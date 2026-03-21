import { useState } from 'react'
import { Modal, Input, Sel, Btn, ADMIN_PIN, uuid } from '../App'
import * as db from '../lib/db'

export default function SetupTab({
  players, fineTypes, seasons, matches,
  setPlayers, setFineTypes, setSeasons, setMatches,
  withSave, currentUser, profile, setProfile, currentTeamId, currentTeam, currentTeamRole,
  onOpenProfile, onOpenTeams, onOpenTeamManagement, onSignOut,
}) {
  const [section, setSection] = useState('hub')
  const canManageTeam = currentTeamRole === 'captain' || currentTeamRole === 'admin'
  const sections = canManageTeam ? ['hub', 'account', 'data'] : ['hub', 'account']

  // ── Player state ──────────────────────────────────────────────────────────
  const [playerInput, setPlayerInput]             = useState({ name: '', email: '', mobile: '', preferredAuthMethod: 'email' })
  const [editPlayer, setEditPlayer]               = useState(null)
  const [confirmDeletePlayer, setConfirmDeletePlayer] = useState(null)
  const [playerPinInput, setPlayerPinInput] = useState('')
  const [playerPinError, setPlayerPinError] = useState('')

  const [fineInput, setFineInput] = useState({ name: '', cost: '' })
  const [editFineType, setEditFineType] = useState(null)
  const [confirmDeleteFine, setConfirmDeleteFine] = useState(null)
  const [finePinInput, setFinePinInput] = useState('')
  const [finePinError, setFinePinError] = useState('')

  const [seasonInput, setSeasonInput] = useState({ name: '', type: 'League' })
  const [editSeason, setEditSeason] = useState(null)
  const [confirmDeleteSeason, setConfirmDeleteSeason] = useState(null)
  const [deletePinInput, setDeletePinInput] = useState('')
  const [deletePinError, setDeletePinError] = useState('')

  const [importText, setImportText] = useState('')
  const [importError, setImportError] = useState('')
  const [importSuccess, setImportSuccess] = useState(false)
  const [importing, setImporting] = useState(false)

  const normalizeAuthDetails = player => {
    const email = player.email?.trim().toLowerCase() ?? ''
    const mobile = player.mobile?.trim() ?? ''

    if (!email && !mobile) {
      throw new Error('Player auth needs an email, mobile number, or both.')
    }

    const preferredAuthMethod = player.preferredAuthMethod === 'whatsapp' ? 'whatsapp' : 'email'
    if (preferredAuthMethod === 'email' && !email) throw new Error('Default method is Email, but no email is set.')
    if (preferredAuthMethod === 'whatsapp' && !mobile) throw new Error('Default method is WhatsApp, but no mobile number is set.')

    return { email, mobile, preferredAuthMethod }
  }

  // ── Players ───────────────────────────────────────────────────────────────
  const addPlayer = () => withSave(async () => {
    const name = playerInput.name.trim()
    if (!name) return
    const authDetails = normalizeAuthDetails(playerInput)
    const p = await db.addPlayer({ id: uuid(), name, ...authDetails })
    setPlayers(prev => [...prev, p].sort((a, b) => a.name.localeCompare(b.name)))
    setPlayerInput({ name: '', email: '', mobile: '', preferredAuthMethod: 'email' })
  })

  const saveEditPlayer = () => withSave(async () => {
    if (!editPlayer?.name.trim()) return
    const authDetails = normalizeAuthDetails(editPlayer)
    const updated = await db.updatePlayer({ ...editPlayer, ...authDetails })
    setPlayers(prev => prev.map(p => p.id === updated.id ? updated : p))
    setEditPlayer(null)
  })

  const confirmPlayerDelete = () => withSave(async () => {
    if (playerPinInput !== ADMIN_PIN) { setPlayerPinError('Incorrect PIN'); return }
    await db.deletePlayer(confirmDeletePlayer.id)
    setPlayers(prev => prev.filter(p => p.id !== confirmDeletePlayer.id))
    setConfirmDeletePlayer(null); setPlayerPinInput(''); setPlayerPinError('')
  })

  const addFine = () => withSave(async () => {
    if (!fineInput.name.trim() || !fineInput.cost) return
    const ft = await db.addFineType({ id: uuid(), name: fineInput.name.trim(), cost: parseFloat(fineInput.cost), teamId: currentTeamId })
    setFineTypes(prev => [...prev, ft].sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)))
    setFineInput({ name: '', cost: '' })
  })

  const saveEditFineType = () => withSave(async () => {
    if (!editFineType?.name.trim() || !editFineType.cost) return
    const updated = await db.updateFineType({ ...editFineType, cost: parseFloat(editFineType.cost), teamId: currentTeamId })
    setFineTypes(prev => prev.map(f => f.id === updated.id ? updated : f))
    setEditFineType(null)
  })

  const confirmFineDelete = () => withSave(async () => {
    if (finePinInput !== ADMIN_PIN) { setFinePinError('Incorrect PIN'); return }
    await db.deleteFineType(confirmDeleteFine.id)
    setFineTypes(prev => prev.filter(f => f.id !== confirmDeleteFine.id))
    setConfirmDeleteFine(null); setFinePinInput(''); setFinePinError('')
  })

  const addSeason = () => withSave(async () => {
    if (!seasonInput.name.trim()) return
    const s = await db.addSeason({ id: uuid(), name: seasonInput.name.trim(), type: seasonInput.type, teamId: currentTeamId })
    setSeasons(prev => [...prev, s].sort((a, b) => a.name.localeCompare(b.name)))
    setSeasonInput({ name: '', type: 'League' })
  })

  const saveEditSeason = () => withSave(async () => {
    if (!editSeason?.name.trim()) return
    const updated = await db.updateSeason({ ...editSeason, teamId: currentTeamId })
    setSeasons(prev => prev.map(s => s.id === updated.id ? updated : s))
    setEditSeason(null)
  })

  const confirmSeasonDelete = () => withSave(async () => {
    if (deletePinInput !== ADMIN_PIN) { setDeletePinError('Incorrect PIN'); return }
    await db.deleteSeason(confirmDeleteSeason.id)
    setSeasons(prev => prev.filter(s => s.id !== confirmDeleteSeason.id))
    setConfirmDeleteSeason(null); setDeletePinInput(''); setDeletePinError('')
  })

  const handleImport = async () => {
    try {
      const data = JSON.parse(importText.trim())
      if (!Array.isArray(data.players) || !Array.isArray(data.fineTypes) || !Array.isArray(data.seasons) || !Array.isArray(data.matches)) {
        setImportError('Invalid format — missing required fields.'); return
      }
      setImporting(true)
      await db.importAll(data)
      setPlayers(data.players)
      setFineTypes(data.fineTypes)
      setSeasons(data.seasons)
      setMatches(data.matches)
      setImportText(''); setImportError(''); setImportSuccess(true)
    } catch (e) {
      setImportError(e.message?.includes('JSON') ? 'Could not parse JSON — paste the full file contents.' : `Import failed: ${e.message}`)
    } finally {
      setImporting(false)
    }
  }

  const handleExport = () => {
    const data = { players, fineTypes, seasons, matches, exportedAt: new Date().toISOString() }
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `white-horse-pool-fines-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div>
      <div className="space-y-4">
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">More</p>
              <h2 className="font-display text-2xl font-bold text-white mt-1">Account & team hub</h2>
              <p className="text-sm text-zinc-400 mt-1">Access profile, team management, and other non-match actions from one place.</p>
            </div>
            {currentTeam && (
              <div className="text-right text-xs text-zinc-500">
                <div>Current team</div>
                <div className="text-white font-bold mt-1">{currentTeam.name}</div>
              </div>
            )}
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mt-4">
            <Btn onClick={onOpenProfile} className="w-full">Profile</Btn>
            <Btn variant="outline" onClick={currentTeam ? onOpenTeamManagement : onOpenTeams} className="w-full">{currentTeam ? 'Team Management' : 'Teams'}</Btn>
            <Btn variant="ghost" onClick={onSignOut} className="w-full">Sign out</Btn>
          </div>
        </div>

        {currentTeam && (
          <div className="bg-zinc-900/70 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-zinc-400">
            Team-specific seasons and fine types now live in Team Management for <span className="text-white font-bold">{currentTeam.name}</span>.
            <span className="block mt-1">Use the selected team page for roster, invites, fines, and seasons so setup no longer duplicates those controls.</span>
          </div>
        )}
      </div>

      <div className="flex gap-1 mb-4 mt-4 bg-zinc-800 rounded-xl p-1 overflow-x-auto">
        {sections.map(s => (
          <button key={s} onClick={() => setSection(s)}
            className={`flex-1 py-1.5 rounded-lg text-xs font-bold capitalize transition-all ${section === s ? 'bg-amber-500 text-zinc-900' : 'text-zinc-400 hover:text-white'}`}>
            {s}
          </button>
        ))}
      </div>

      {section === 'hub' && (
        <div className="space-y-3">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
            Use this area for account access, team switching, and setup tools that are outside the day-to-day Dashboard, Matches, and Fines workflow.
          </div>
          {!canManageTeam && (
            <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 text-sm text-zinc-400">
              Team setup tools are limited to captains and vice-captains, but your Profile and Teams pages are available above.
            </div>
          )}
          {canManageTeam && (
            <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 text-sm text-zinc-400">
              Captains and vice-captains can use Team Management for team configuration, while this area stays focused on account access and data import/export.
            </div>
          )}
        </div>
      )}

      {section === 'players' && (
        <div>
          <div className="bg-zinc-800 rounded-xl p-3 mb-4">
            <Input label="Player Name" value={playerInput.name} onChange={e => setPlayerInput(p => ({ ...p, name: e.target.value }))}
              onKeyDown={e => e.key === 'Enter' && addPlayer()} placeholder="Player name" />
            <Input label="Email (optional)" type="email" value={playerInput.email} onChange={e => setPlayerInput(p => ({ ...p, email: e.target.value }))}
              placeholder="name@example.com" />
            <Input label="Mobile (optional)" value={playerInput.mobile} onChange={e => setPlayerInput(p => ({ ...p, mobile: e.target.value }))}
              placeholder="+447700900123" />
            <Sel label="Default Authentication Method" value={playerInput.preferredAuthMethod} onChange={e => setPlayerInput(p => ({ ...p, preferredAuthMethod: e.target.value }))}>
              <option value="email">Email OTP</option>
              <option value="whatsapp">WhatsApp OTP</option>
            </Sel>
            <Btn onClick={addPlayer} className="w-full">Add Player</Btn>
          </div>
          <div className="space-y-2">
            {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => (
              <div key={p.id} className="flex items-center justify-between bg-zinc-800 rounded-lg px-3 py-2 gap-3">
                <div>
                  <span className="text-white text-sm font-medium">🎱 {p.name}</span>
                  <div className="text-xs text-zinc-400 mt-0.5">
                    {p.email ? <span>{p.email}</span> : <span>No email</span>} · {p.mobile ? <span>{p.mobile}</span> : <span>No mobile</span>} · <span className="text-amber-400">Default: {p.preferredAuthMethod === 'whatsapp' ? 'WhatsApp' : 'Email'}</span>
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button onClick={() => setEditPlayer({
                    id: p.id,
                    name: p.name,
                    email: p.email ?? '',
                    mobile: p.mobile ?? '',
                    preferredAuthMethod: p.preferredAuthMethod ?? 'email',
                    authUserId: p.authUserId ?? null,
                  })}
                    className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300 font-bold">Edit</button>
                  <button onClick={() => { setConfirmDeletePlayer(p); setPlayerPinInput(''); setPlayerPinError('') }}
                    className="text-red-400 hover:text-red-300 text-xl leading-none">×</button>
                </div>
              </div>
            ))}
            {!players.length && <p className="text-zinc-500 text-sm text-center py-6">No players added yet</p>}
          </div>
          {confirmDeletePlayer && (
            <Modal title="Delete Player" onClose={() => setConfirmDeletePlayer(null)}>
              <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{confirmDeletePlayer.name}</strong>? Enter admin PIN to confirm.</p>
              <Input label="Admin PIN" type="password" value={playerPinInput} onChange={e => setPlayerPinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && confirmPlayerDelete()} placeholder="Enter PIN" />
              {playerPinError && <p className="text-red-400 text-sm mb-2">{playerPinError}</p>}
              <div className="flex gap-2"><Btn variant="danger" className="flex-1" onClick={confirmPlayerDelete}>Delete Player</Btn><Btn variant="ghost" className="flex-1" onClick={() => setConfirmDeletePlayer(null)}>Cancel</Btn></div>
            </Modal>
          )}
          {editPlayer && (
            <Modal title="Edit Player" onClose={() => setEditPlayer(null)}>
              <Input label="Player Name" value={editPlayer.name} onChange={e => setEditPlayer(p => ({ ...p, name: e.target.value }))} placeholder="Player name" />
              <Input label="Email (optional)" type="email" value={editPlayer.email ?? ''} onChange={e => setEditPlayer(p => ({ ...p, email: e.target.value }))} placeholder="name@example.com" />
              <Input label="Mobile (optional)" value={editPlayer.mobile ?? ''} onChange={e => setEditPlayer(p => ({ ...p, mobile: e.target.value }))} placeholder="+447700900123" />
              <Sel label="Default Authentication Method" value={editPlayer.preferredAuthMethod ?? 'email'} onChange={e => setEditPlayer(p => ({ ...p, preferredAuthMethod: e.target.value }))}>
                <option value="email">Email OTP</option>
                <option value="whatsapp">WhatsApp OTP</option>
              </Sel>
              <div className="flex gap-2 mt-1">
                <Btn onClick={saveEditPlayer} className="flex-1">Save</Btn>
                <Btn variant="ghost" onClick={() => setEditPlayer(null)} className="flex-1">Cancel</Btn>
              </div>
            </Modal>
          )}
        </div>
      )}

      {section === 'account' && (
        <div className="space-y-3">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
            Profile access, team switching, and sign-out stay here. Team-specific configuration now lives inside Team Management.
          </div>
          {currentTeam && (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
                <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Fines</p>
                <h3 className="text-white font-bold mt-1">Manage fine types from the team</h3>
                <p className="text-sm text-zinc-400 mt-2">Add, edit, and remove {currentTeam.name}&apos;s fine types from Team Management → Fines.</p>
                <Btn variant="outline" className="mt-3 w-full" onClick={onOpenTeamManagement}>Open Team Management</Btn>
              </div>
              <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
                <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Seasons</p>
                <h3 className="text-white font-bold mt-1">Manage seasons from the team</h3>
                <p className="text-sm text-zinc-400 mt-2">Create and edit {currentTeam.name}&apos;s seasons from Team Management → Seasons.</p>
                <Btn variant="outline" className="mt-3 w-full" onClick={onOpenTeamManagement}>Open Team Management</Btn>
              </div>
            </div>
          )}
        </div>
      )}

      {section === 'data' && (
        <div>
          <div className="bg-zinc-800 rounded-xl p-3 mb-4">
            <h3 className="font-bold text-white mb-2">Export data</h3>
            <Btn onClick={handleExport} className="w-full">Export JSON backup</Btn>
          </div>

          <div className="bg-zinc-800 rounded-xl p-3">
            <h3 className="font-bold text-white mb-2">Import data</h3>
            <textarea value={importText} onChange={e => setImportText(e.target.value)} rows={8} className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-zinc-200 text-xs mb-2" placeholder="Paste JSON backup here..." />
            {importError && <p className="text-red-400 text-xs mb-2">{importError}</p>}
            {importSuccess && <p className="text-emerald-400 text-xs mb-2">Import complete.</p>}
            <Btn variant="danger" className="w-full" onClick={handleImport} disabled={importing}>{importing ? 'Importing...' : 'Import JSON (overwrite all data)'}</Btn>
          </div>
        </div>
      )}
    </div>
  )
}
