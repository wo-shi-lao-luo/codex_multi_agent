/** Schema v4 protects workspace and executor identity fields from older, unaware writers. */
export const SCHEMA_VERSION = 4;
export const APPLICATION_ID = 0x54424f41;

// Each relationship is a real row. JSON holds extensible work-package details, not a second board.
export const repositoryDefinitions = {
  tasks: { table: 'tasks', fields: { taskRevision: 'INTEGER NOT NULL', state: 'TEXT NOT NULL' } },
  workers: { table: 'workers', fields: {} },
  dependencies: {
    table: 'task_dependencies',
    fields: {
      taskId: 'TEXT NOT NULL REFERENCES tasks(id)',
      dependsOnTaskId: 'TEXT NOT NULL REFERENCES tasks(id)',
      gate: "TEXT NOT NULL CHECK (gate IN ('accepted-result', 'frozen-submission'))",
    },
  },
  grants: {
    table: 'grants',
    fields: {
      taskId: 'TEXT NOT NULL REFERENCES tasks(id)',
      workerId: 'TEXT NOT NULL REFERENCES workers(id)',
      approvalRevision: 'INTEGER NOT NULL',
    },
  },
  assignments: {
    table: 'assignments',
    fields: {
      taskId: 'TEXT NOT NULL REFERENCES tasks(id)',
      workerId: 'TEXT NOT NULL REFERENCES workers(id)',
      active: 'INTEGER NOT NULL CHECK (active IN (0, 1))',
    },
  },
  taskResources: {
    table: 'task_resources',
    fields: { taskId: 'TEXT NOT NULL REFERENCES tasks(id)' },
  },
  reservations: {
    table: 'reservations',
    fields: {
      taskId: 'TEXT NOT NULL REFERENCES tasks(id)',
      assignmentId: 'TEXT NOT NULL REFERENCES assignments(id)',
      active: 'INTEGER NOT NULL CHECK (active IN (0, 1))',
    },
  },
  submissions: {
    table: 'submissions',
    fields: {
      taskId: 'TEXT NOT NULL REFERENCES tasks(id)',
      assignmentId: 'TEXT NOT NULL REFERENCES assignments(id)',
      taskRevision: 'INTEGER NOT NULL',
    },
  },
  questions: {
    table: 'questions',
    fields: {
      taskId: 'TEXT NOT NULL REFERENCES tasks(id)',
      assignmentId: 'TEXT NOT NULL REFERENCES assignments(id)',
    },
  },
  answers: {
    table: 'answers',
    fields: { questionId: 'TEXT NOT NULL REFERENCES questions(id)' },
  },
};

/** Create the sole initial schema inside the caller's exclusive initialization transaction. */
export function createSchema(db) {
  db.exec(`
    CREATE TABLE boards (id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL);
    CREATE TABLE operation_receipts (
      id TEXT PRIMARY KEY, request_hash TEXT NOT NULL, generation TEXT NOT NULL,
      payload TEXT NOT NULL
    );
    CREATE TABLE audit_events (
      sequence INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT NOT NULL,
      type TEXT NOT NULL, payload TEXT NOT NULL
    );
    CREATE TABLE change_events (
      sequence INTEGER PRIMARY KEY, generation TEXT NOT NULL,
      type TEXT NOT NULL, payload TEXT NOT NULL
    );
  `);
  for (const { table, fields } of Object.values(repositoryDefinitions)) {
    const columns = Object.entries(fields).map(([name, type]) => `${name} ${type}`);
    db.exec(`CREATE TABLE ${table} (
      id TEXT PRIMARY KEY, payload TEXT NOT NULL${columns.length ? ', ' : ''}${columns.join(', ')}
    )`);
    for (const name of Object.keys(fields).filter((name) => name.endsWith('Id'))) {
      db.exec(`CREATE INDEX ${table}_${name} ON ${table} (${name})`);
    }
  }
  db.exec(`
    CREATE UNIQUE INDEX one_active_assignment ON assignments(taskId) WHERE active = 1;
    CREATE UNIQUE INDEX unique_dependency ON task_dependencies(taskId, dependsOnTaskId);
    PRAGMA user_version = ${SCHEMA_VERSION};
    PRAGMA application_id = ${APPLICATION_ID};
  `);
}
