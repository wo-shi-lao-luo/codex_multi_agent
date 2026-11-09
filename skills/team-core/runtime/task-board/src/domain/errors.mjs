/** Stable errors shared by the CLI and coordination services; details must contain no credentials. */
export class BoardError extends Error {
  /** Construct a machine-readable failure without attaching raw requests or tokens. */
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'BoardError';
    this.code = code;
    this.details = details;
  }
}
