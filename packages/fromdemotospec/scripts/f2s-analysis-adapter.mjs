// Compatibility entrypoint for pre-1.1 callers.
import {runCli} from './fromdemotospec-analysis-adapter.mjs';
export * from './fromdemotospec-analysis-adapter.mjs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) await runCli();
