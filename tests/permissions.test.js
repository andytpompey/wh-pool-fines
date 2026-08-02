import test from 'node:test'
import assert from 'node:assert/strict'
import {
  PROTECTED_ACTION,
  canManageTeamOperations,
  canManageTeamRoles,
  canPerformProtectedAction,
  normaliseTeamRole,
} from '../src/lib/permissions.js'

const active = role => ({ role, status: 'active' })

test('only active leaders manage team operations', () => {
  assert.equal(canManageTeamOperations({ membership: active('captain') }), true)
  assert.equal(canManageTeamOperations({ membership: active('vice_captain') }), true)
  assert.equal(canManageTeamOperations({ membership: active('member') }), false)
  assert.equal(canManageTeamOperations({ membership: { role: 'captain', status: 'removed' } }), false)
})

test('only captain manages roles', () => {
  assert.equal(canManageTeamRoles({ membership: active('captain') }), true)
  assert.equal(canManageTeamRoles({ membership: active('vice_captain') }), false)
})

test('protected actions require active leader and verified unlock', () => {
  assert.equal(canPerformProtectedAction({ action: PROTECTED_ACTION.DELETE_FINE_ENTRY, membership: active('captain'), unlockCodeVerified: true }), true)
  assert.equal(canPerformProtectedAction({ action: PROTECTED_ACTION.DELETE_FINE_ENTRY, membership: active('captain'), unlockCodeVerified: false }), false)
  assert.equal(canPerformProtectedAction({ action: PROTECTED_ACTION.DELETE_FINE_ENTRY, membership: active('member'), unlockCodeVerified: true }), false)
  assert.equal(canPerformProtectedAction({ action: PROTECTED_ACTION.DELETE_FINE_ENTRY, membership: active('captain'), platformRole: 'admin', unlockCodeVerified: true }), false)
})

test('legacy team admin normalises to vice-captain', () => {
  assert.equal(normaliseTeamRole('admin'), 'vice_captain')
})
