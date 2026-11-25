import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { publicSnapshot } from '../coordination/service.mjs';

const DETAIL_LIMIT = 20;

function displayText(value, limit = 2000) {
  return typeof value === 'string' ? value.slice(0, limit) : null;
}

function displayList(items, format = displayText) {
  return (Array.isArray(items) ? items : []).slice(0, DETAIL_LIMIT)
    .map(item => format(item)).filter(Boolean);
}

function relativeLabel(value) {
  if (typeof value !== 'string' || path.posix.isAbsolute(value) || path.win32.isAbsolute(value)) {
    return null;
  }
  return displayText(value, 280);
}

function referenceLabel(value, roots) {
  if (typeof value !== 'string') return null;
  if (/^file:/i.test(value)) {
    try {
      const url = new URL(value);
      value = fileURLToPath(url, { windows: Boolean(url.hostname) || /^\/[a-z]:/i.test(url.pathname) });
    } catch {
      return null;
    }
  }
  const pathStyle = /^\/(?!\/)/.test(value) ? path.posix : path.win32;
  if (!pathStyle.isAbsolute(value)) return displayText(value);

  for (const root of roots) {
    if (pathStyle === path.posix && !/^\/(?!\/)/.test(root)) continue;
    if (pathStyle === path.win32 && /^\/(?!\/)/.test(root)) continue;
    const relative = pathStyle.relative(root, value);
    if (relative && !pathStyle.isAbsolute(relative) && relative !== '..' &&
        !relative.startsWith(`..${pathStyle.sep}`)) {
      return displayText(relative.replaceAll(pathStyle.sep, '/'));
    }
  }
  return null;
}

function sourceLabel(reference, formatReference) {
  if (typeof reference === 'string') return formatReference(reference);
  if (reference?.kind === 'work') return relativeLabel(reference.path);
  const changeId = reference?.kind === 'openspec' && displayText(reference.changeId, 280);
  return changeId ? `OpenSpec · ${changeId}` : null;
}

function byKey(items, key) {
  const grouped = new Map();
  for (const item of items) {
    const id = item[key];
    if (!grouped.has(id)) grouped.set(id, []);
    grouped.get(id).push(item);
  }
  return grouped;
}

function personOf(record) {
  const executor = record?.actualExecutor ?? record;
  const id = displayText(executor?.workerId, 160);
  return id ? { id, role: displayText(executor.role, 160) } : null;
}

function submissionPerson(submission, assignments) {
  if (!submission) return null;
  return personOf(submission) ??
    personOf(assignments.find(item => item.id === submission.assignmentId));
}

// A closed result names its accepted submission. A pending result must match the one live freeze.
function attributedSubmission(task, submissions) {
  if (task.state === 'closed') {
    const submissionId = task.acceptedResult?.submissionId;
    return submissionId ? submissions.find(item => item.id === submissionId) : null;
  }
  if (task.state !== 'submitted' || !Number.isSafeInteger(task.freezeRevision)) return null;
  const matches = submissions.filter(item => item.freezeValid === true &&
    item.freezeRevision === task.freezeRevision &&
    (task.executionRevision === undefined || item.executionRevision === task.executionRevision) &&
    (task.approvalRevision === undefined || item.approvalRevision === task.approvalRevision) &&
    (task.inputRevision === undefined || item.boundTaskInputRevision === task.inputRevision));
  return matches.length === 1 ? matches[0] : null;
}

function responsibilityFor(task, active, attributed, assignments) {
  if (task.state === 'canceled') return { kind: 'canceled', person: null };
  if (task.state === 'submitted') {
    return { kind: 'submitter', person: submissionPerson(attributed, assignments) };
  }
  if (task.state === 'closed') {
    return { kind: task.resultValid === false ? 'historical' : 'completed',
      person: submissionPerson(attributed, assignments) };
  }
  const person = personOf(active);
  return { kind: person ? 'executor' : 'unassigned', person };
}

function submissionDetails(submissions, task, assignments, attributed, formatReference) {
  const historyLimit = attributed ? DETAIL_LIMIT - 1 : DETAIL_LIMIT;
  const history = submissions.filter(item => item !== attributed)
    .sort((left, right) => (right.taskRevision ?? 0) - (left.taskRevision ?? 0))
    .slice(0, historyLimit);
  if (attributed) history.unshift(attributed);
  return history.map(item => {
    let kind = 'historical';
    if (item === attributed) {
      if (task.state === 'submitted') kind = 'current';
      else kind = task.resultValid === false ? 'invalid' : 'accepted';
    }
    return { kind, person: submissionPerson(item, assignments),
      evidenceRefs: displayList(item.evidenceRefs, formatReference) };
  });
}

function questionDetails(question, answers, formatReference) {
  const applied = question.state === 'applied' || question.status === 'applied';
  const stale = question.stale === true || question.state === 'stale' || question.status === 'stale';
  let status = answers.length ? 'answered' : 'pending';
  if (applied) status = 'applied';
  else if (question.approvalPending === true) {
    status = stale ? 'stale-approval-pending' : 'approval-pending';
  }
  else if (stale) status = 'stale';
  return {
    question: displayText(question.question),
    step: displayText(question.step),
    impact: displayText(question.impact),
    options: displayList(question.options),
    recommendation: displayText(question.recommendation),
    checkedRefs: displayList(question.checkedRefs, formatReference),
    status,
    answers: [...answers].sort((left, right) => (right.answerRevision ?? 0) - (left.answerRevision ?? 0))
      .slice(0, DETAIL_LIMIT).map(answer => ({
        text: displayText(answer.text),
        decision: displayText(answer.decision, 80),
        evidenceRefs: displayList(answer.evidenceRefs, formatReference),
      })),
  };
}

// Coordination-generated blockers embed a private question ID in their diagnostic text.
function blockerFor(task, questions) {
  for (const question of questions) {
    if (task.blocker === `Question ${question.id}: ${question.step}`) {
      return displayText(`Question: ${question.step}`, 280);
    }
    if (task.blocker === `Approval decision ${question.id} remains unresolved.`) {
      return 'Approval decision remains unresolved.';
    }
  }
  return displayText(task.blocker, 280);
}

// Physical reservation keys hold canonical local paths, so file scopes use declared relative paths.
function taskResources(task) {
  const scopes = (values, mode) => displayList(values,
    value => relativeLabel(typeof value === 'string' ? value : value?.path))
    .map(key => ({ kind: 'path', key, mode }));
  return [
    ...displayList(task.resources, resource => {
      const key = relativeLabel(resource?.key);
      return key && resource.kind === 'resource' && ['shared', 'exclusive'].includes(resource.mode)
        ? { kind: 'resource', key, mode: resource.mode } : null;
    }),
    ...scopes(task.scope?.write, 'exclusive'),
    ...scopes(task.scope?.read, 'shared'),
  ].slice(0, DETAIL_LIMIT);
}

/** Project only the labels, status and evidence needed by the standalone cards. */
export function dashboardTasks(snapshot) {
  const view = publicSnapshot(snapshot);
  const roots = [snapshot.board.projectRoot, ...(snapshot.board.workspaces ?? []).map(item => item?.root)]
    .filter(root => typeof root === 'string' && (path.win32.isAbsolute(root) || path.posix.isAbsolute(root)))
    .sort((left, right) => right.length - left.length);
  const formatReference = value => referenceLabel(value, roots);
  const assignmentsByTask = byKey(view.assignments, 'taskId');
  const submissionsByTask = byKey(view.submissions, 'taskId');
  const dependenciesByTask = byKey(view.dependencies, 'taskId');
  const questionsByTask = byKey(view.questions, 'taskId');
  const answersByQuestion = byKey(view.answers, 'questionId');
  const taskTitles = new Map(snapshot.tasks.map(task => [task.id, displayText(task.title, 160)]));

  return view.tasks.map(task => {
    const assignments = assignmentsByTask.get(task.id) ?? [];
    const submissions = submissionsByTask.get(task.id) ?? [];
    const dependencies = dependenciesByTask.get(task.id) ?? [];
    const questions = questionsByTask.get(task.id) ?? [];
    const active = assignments.find(item => item.active === true);
    const attributed = attributedSubmission(task, submissions);
    const questionViews = questions.map(item =>
      questionDetails(item, answersByQuestion.get(item.id) ?? [], formatReference));
    const pendingQuestions = questionViews.filter(item => !['applied', 'stale'].includes(item.status));
    const historicalQuestions = questionViews.filter(item => ['applied', 'stale'].includes(item.status));

    return {
      id: task.id,
      title: taskTitles.get(task.id) ?? '',
      state: task.state,
      phase: displayText(task.phase, 80),
      progress: displayText(task.progress, 280) ?? '',
      updatedAt: displayText(task.updatedAt, 80),
      lastReportAt: displayText(task.lastReportAt, 80),
      eligibleRoles: displayList(task.eligibleRoles, value => displayText(value, 160)),
      allowLeadInline: task.allowLeadInline === true,
      readiness: task.readiness,
      readinessReason: displayText(task.readinessReason, 280),
      nextCheckpoint: displayText(task.nextCheckpoint, 280),
      blocker: blockerFor(task, questions),
      cleanupPending: task.cleanupPending === true,
      needsReconcile: task.needsReconcile === true,
      resultValid: typeof task.resultValid === 'boolean' ? task.resultValid : null,
      cancellationReason: displayText(task.cancellation?.reason, 280),
      dependencyCount: dependencies.length,
      pendingQuestionCount: pendingQuestions.length,
      responsibility: responsibilityFor(task, active, attributed, assignments),
      details: {
        outcome: displayText(task.outcome),
        responsibilities: displayList(task.responsibilities),
        sourceRefs: displayList(task.sourceRefs, item => sourceLabel(item, formatReference)),
        acceptanceRefs: displayList(task.acceptanceRefs, formatReference),
        acceptanceEvidence: displayList(task.acceptanceEvidence, formatReference),
        executionHistory: assignments.slice(-DETAIL_LIMIT).map(item => ({
          person: personOf(item), active: item.active === true,
        })),
        submissions: submissionDetails(submissions, task, assignments, attributed, formatReference),
        dependencies: dependencies.slice(0, DETAIL_LIMIT).map(edge => ({
          title: taskTitles.get(edge.dependsOnTaskId) ?? null,
          gate: displayText(edge.gate, 80),
        })),
        resources: taskResources(task),
        questions: [...pendingQuestions, ...historicalQuestions].slice(0, DETAIL_LIMIT),
      },
    };
  });
}
