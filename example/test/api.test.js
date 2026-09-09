import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../src/api.js';
test('server exists', () => { assert.ok(createServer()); });
