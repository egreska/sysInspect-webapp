import { cloudKitAdapter } from './cloudKitAdapter';
import { createLoad } from './load';

export const load = createLoad(cloudKitAdapter);
