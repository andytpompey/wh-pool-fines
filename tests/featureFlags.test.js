import test from 'node:test'
import assert from 'node:assert/strict'

import { isEnabledFeatureFlag } from '../src/lib/featureFlags.js'

test('commercial features require an explicit true flag', () => {
  assert.equal(isEnabledFeatureFlag(undefined), false)
  assert.equal(isEnabledFeatureFlag(''), false)
  assert.equal(isEnabledFeatureFlag('false'), false)
  assert.equal(isEnabledFeatureFlag('1'), false)
  assert.equal(isEnabledFeatureFlag('true'), true)
  assert.equal(isEnabledFeatureFlag(' TRUE '), true)
})
