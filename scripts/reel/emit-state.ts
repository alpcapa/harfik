import { sahne, HAMLE, RAF } from './state';
console.log(JSON.stringify({ payload: { version: 1, state: sahne(), savedAt: Date.now() }, HAMLE, RAF }));
