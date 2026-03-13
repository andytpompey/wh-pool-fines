import { useState } from 'react'
import { Badge, Modal, Input, Sel, Btn, ADMIN_PIN, uuid } from '../App'
import * as db from '../lib/db'

export default function SetupTab({ players, fineTypes, seasons, matches, setPlayers, setFineTypes, setSeasons, setMatches, withSave }) {
  const [section, setSection] = useState('players')

  // ── Player state ──────────────────────────────────────────────────────────
  const [playerInput, setPlayerInput]             = useState('')
  const [editPlayer, setEditPlayer]               = useState(null)
  const [confirmDeletePlayer, setConfirmDeletePlayer] = useState(null)
  const [playerPinInput, setPlayerPinInput]       = useState('')
  const [playerPinError, setPlayerPinError]       = useState('')

  // ── Fine type state ───────────────────────────────────────────────────────
  const [fineInput, setFineInput]                 = useState({ name: '', cost: '' })
  const [editFineType, setEditFineType]           = useState(null)
  const [confirmDeleteFine, setConfirmDeleteFine] = useState(null)
  const [finePinInput, setFinePinInput]           = useState('')
  const [finePinError, setFinePinError]           = useState('')

  // ── Season state ──────────────────────────────────────────────────────────
  const [seasonInput, setSeasonInput]             = useState({ name: '', type: 'League' })
  const [editSeason, setEditSeason]               = useState(null)
  const [confirmDeleteSeason, setConfirmDeleteSeason] = useState(null)
  const [deletePinInput, setDeletePinInput]       = useState('')
  const [deletePinError, setDeletePinError]       = useState('')

  // ── Import/Export state ───────────────────────────────────────────────────
  const [importText, setImportText]       = useState('')
  const [importError, setImportError]     = useState('')
  const [importSuccess, setImportSuccess] = useState(false)
  const [importing, setImporting]         = useState(false)

  // ── Players ───────────────────────────────────────────────────────────────
  const addPlayer = () => withSave(async () => {
    const name = playerInput.trim()
    if (!name) return
    const p = await db.addPlayer({ id: uuid(), name })
    setPlayers(prev => [...prev, p].sort((a, b) => a.name.localeCompare(b.name)))
    setPlayerInput('')
  })

  const saveEditPlayer = () => withSave(async () => {
    if (!editPlayer?.name.trim()) return
    const updated = await db.updatePlayer(editPlayer)
    setPlayers(prev => prev.map(p => p.id === updated.id ? updated : p))
    setEditPlayer(null)
  })

  const confirmPlayerDelete = () => withSave(async () => {
    if (playerPinInput !== ADMIN_PIN) { setPlayerPinError('Incorrect PIN'); return }
    await db.deletePlayer(confirmDeletePlayer.id)
    setPlayers(prev => prev.filter(p => p.id !== confirmDeletePlayer.id))
    setConfirmDeletePlayer(null); setPlayerPinInput(''); setPlayerPinError('')
  })

  // ── Fine types ────────────────────────────────────────────────────────────
  const addFine = () => withSave(async () => {
    if (!fineInput.name.trim() || !fineInput.cost) return
    const ft = await db.addFineType({ id: uuid(), name: fineInput.name.trim(), cost: parseFloat(fineInput.cost) })
    setFineTypes(prev => [...prev, ft].sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)))
    setFineInput({ name: '', cost: '' })
  })

  const saveEditFineType = () => withSave(async () => {
    if (!editFineType?.name.trim() || !editFineType.cost) return
    const updated = await db.updateFineType({ ...editFineType, cost: parseFloat(editFineType.cost) })
    setFineTypes(prev => prev.map(f => f.id === updated.id ? updated : f))
    setEditFineType(null)
  })

  const confirmFineDelete = () => withSave(async () => {
    if (finePinInput !== ADMIN_PIN) { setFinePinError('Incorrect PIN'); return }
    await db.deleteFineType(confirmDeleteFine.id)
    setFineTypes(prev => prev.filter(f => f.id !== confirmDeleteFine.id))
    setConfirmDeleteFine(null); setFinePinInput(''); setFinePinError('')
  })

  // ── Seasons ───────────────────────────────────────────────────────────────
  const addSeason = () => withSave(async () => {
    if (!seasonInput.name.trim()) return
    const s = await db.addSeason({ id: uuid(), name: seasonInput.name.trim(), type: seasonInput.type })
    setSeasons(prev => [...prev, s].sort((a, b) => a.name.localeCompare(b.name)))
    setSeasonInput({ name: '', type: 'League' })
  })

  const saveEditSeason = () => withSave(async () => {
    if (!editSeason?.name.trim()) return
    const updated = await db.updateSeason(editSeason)
    setSeasons(prev => prev.map(s => s.id === updated.id ? updated : s))
    setEditSeason(null)
  })

  const confirmSeasonDelete = () => withSave(async () => {
    if (deletePinInput !== ADMIN_PIN) { setDeletePinError('Incorrect PIN'); return }
    await db.deleteSeason(confirmDeleteSeason.id)
    setSeasons(prev => prev.filter(s => s.id !== confirmDeleteSeason.id))
    setConfirmDeleteSeason(null); setDeletePinInput(''); setDeletePinError('')
  })

  // ── Import ────────────────────────────────────────────────────────────────
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

  // ── Export ────────────────────────────────────────────────────────────────
  const handleExport = () => {
    const data = { players, fineTypes, seasons, matches, exportedAt: new Date().toISOString() }
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url  = URL.createObjectURL(blob)
    const a    = document.createElement('a')
    a.href = url
    a.download = `white-horse-pool-fines-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div>
      {/* Section tabs */}
      <div className="flex gap-1 mb-4 bg-zinc-800 rounded-xl p-1">
        {['players', 'fines', 'seasons', 'data'].map(s => (
          <button key={s} onClick={() => setSection(s)}
            className={`flex-1 py-1.5 rounded-lg text-xs font-bold capitalize transition-all ${section === s ? 'bg-amber-500 text-zinc-900' : 'text-zinc-400 hover:text-white'}`}>
            {s}
          </button>
        ))}
      </div>

      {/* ── Players ── */}
      {section === 'players' && (
        <div>
          <div className="flex gap-2 mb-4">
            <input value={playerInput} onChange={e => setPlayerInput(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && addPlayer()}
              placeholder="Player name..."
              className="flex-1 bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-amber-500" />
            <Btn onClick={addPlayer}>Add</Btn>
          </div>
          <div className="space-y-2">
            {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => (
              <div key={p.id} className="flex items-center justify-between bg-zinc-800 rounded-lg px-3 py-2">
                <span className="text-white text-sm font-medium">🎱 {p.name}</span>
                <div className="flex items-center gap-2">
                  <button onClick={() => setEditPlayer({ id: p.id, name: p.name })}
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
              <div className="bg-red-950/50 border border-red-800/50 rounded-lg px-3 py-2 mb-3 text-red-300 text-xs font-medium">Warning: cannot be undone.</div>
              <Input label="Admin PIN" type="password" value={playerPinInput} onChange={e => setPlayerPinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && confirmPlayerDelete()} placeholder="Enter PIN" />
              {playerPinError && <p className="text-red-400 text-sm mb-2">{playerPinError}</p>}
              <div className="flex gap-2">
                <Btn variant="danger" className="flex-1" onClick={confirmPlayerDelete}>Delete Player</Btn>
                <Btn variant="ghost" className="flex-1" onClick={() => setConfirmDeletePlayer(null)}>Cancel</Btn>
              </div>
            </Modal>
          )}
          {editPlayer && (
            <Modal title="Edit Player" onClose={() => setEditPlayer(null)}>
              <Input label="Player Name" value={editPlayer.name} onChange={e => setEditPlayer(p => ({ ...p, name: e.target.value }))} onKeyDown={e => e.key === 'Enter' && saveEditPlayer()} placeholder="Player name" />
              <div className="flex gap-2 mt-1">
                <Btn onClick={saveEditPlayer} className="flex-1">Save</Btn>
                <Btn variant="ghost" onClick={() => setEditPlayer(null)} className="flex-1">Cancel</Btn>
              </div>
            </Modal>
          )}
        </div>
      )}

      {/* ── Fine types ── */}
      {section === 'fines' && (
        <div>
          <div className="bg-zinc-800 rounded-xl p-3 mb-4">
            <Input label="Fine Name" value={fineInput.name} onChange={e => setFineInput(f => ({ ...f, name: e.target.value }))} placeholder="e.g. Ball off table" />
            <Input label="Cost (£)" type="number" step="0.10" min="0" value={fineInput.cost} onChange={e => setFineInput(f => ({ ...f, cost: e.target.value }))} placeholder="0.50" />
            <Btn onClick={addFine} className="w-full">Add Fine Type</Btn>
          </div>
          <div className="space-y-2">
            {[...fineTypes].sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)).map(f => (
              <div key={f.id} className="flex items-center justify-between bg-zinc-800 rounded-lg px-3 py-2">
                <div>
                  <span className="text-white text-sm font-medium">{f.name}</span>
                  <span className="text-amber-400 text-xs font-bold ml-2">£{f.cost.toFixed(2)}</span>
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => setEditFineType({ id: f.id, name: f.name, cost: String(f.cost) })}
                    className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300 font-bold">Edit</button>
                  <button onClick={() => { setConfirmDeleteFine(f); setFinePinInput(''); setFinePinError('') }}
                    className="text-red-400 hover:text-red-300 text-xl leading-none">×</button>
                </div>
              </div>
            ))}
            {!fineTypes.length && <p className="text-zinc-500 text-sm text-center py-6">No fine types added yet</p>}
          </div>

          {confirmDeleteFine && (
            <Modal title="Delete Fine Type" onClose={() => setConfirmDeleteFine(null)}>
              <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{confirmDeleteFine.name}</strong>? Enter admin PIN to confirm.</p>
              <div className="bg-red-950/50 border border-red-800/50 rounded-lg px-3 py-2 mb-3 text-red-300 text-xs font-medium">Warning: cannot be undone.</div>
              <Input label="Admin PIN" type="password" value={finePinInput} onChange={e => setFinePinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && confirmFineDelete()} placeholder="Enter PIN" />
              {finePinError && <p className="text-red-400 text-sm mb-2">{finePinError}</p>}
              <div className="flex gap-2">
                <Btn variant="danger" className="flex-1" onClick={confirmFineDelete}>Delete Fine Type</Btn>
                <Btn variant="ghost" className="flex-1" onClick={() => setConfirmDeleteFine(null)}>Cancel</Btn>
              </div>
            </Modal>
          )}
          {editFineType && (
            <Modal title="Edit Fine Type" onClose={() => setEditFineType(null)}>
              <Input label="Fine Name" value={editFineType.name} onChange={e => setEditFineType(f => ({ ...f, name: e.target.value }))} placeholder="e.g. Ball off table" />
              <Input label="Cost (£)" type="number" step="0.10" min="0" value={editFineType.cost} onChange={e => setEditFineType(f => ({ ...f, cost: e.target.value }))} onKeyDown={e => e.key === 'Enter' && saveEditFineType()} placeholder="0.50" />
              <div className="flex gap-2 mt-1">
                <Btn onClick={saveEditFineType} className="flex-1">Save</Btn>
                <Btn variant="ghost" onClick={() => setEditFineType(null)} className="flex-1">Cancel</Btn>
              </div>
            </Modal>
          )}
        </div>
      )}

      {/* ── Seasons ── */}
      {section === 'seasons' && (
        <div>
          <div className="bg-zinc-800 rounded-xl p-3 mb-4">
            <Input label="Season Name" value={seasonInput.name} onChange={e => setSeasonInput(s => ({ ...s, name: e.target.value }))} placeholder="e.g. 2024/25" />
            <Sel label="Game Type" value={seasonInput.type} onChange={e => setSeasonInput(s => ({ ...s, type: e.target.value }))}>
              <option>League</option>
              <option>Cup</option>
            </Sel>
            <Btn onClick={addSeason} className="w-full">Add Season</Btn>
          </div>
          <div className="space-y-2">
            {[...seasons].sort((a, b) => a.name.localeCompare(b.name)).map(s => (
              <div key={s.id} className="flex items-center justify-between bg-zinc-800 rounded-lg px-3 py-2">
                <div className="flex items-center gap-2">
                  <span className="text-white text-sm font-medium">{s.name}</span>
                  <Badge color={s.type === 'Cup' ? 'amber' : 'blue'}>{s.type}</Badge>
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => setEditSeason({ id: s.id, name: s.name, type: s.type })}
                    className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300 font-bold">Edit</button>
                  <button onClick={() => { setConfirmDeleteSeason(s); setDeletePinInput(''); setDeletePinError('') }}
                    className="text-red-400 hover:text-red-300 text-xl leading-none">×</button>
                </div>
              </div>
            ))}
            {!seasons.length && <p className="text-zinc-500 text-sm text-center py-6">No seasons added yet</p>}
          </div>

          {confirmDeleteSeason && (
            <Modal title="Delete Season" onClose={() => setConfirmDeleteSeason(null)}>
              <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{confirmDeleteSeason.name}</strong>? Enter admin PIN to confirm.</p>
              <div className="bg-red-950/50 border border-red-800/50 rounded-lg px-3 py-2 mb-3 text-red-300 text-xs font-medium">Warning: cannot be undone.</div>
              <Input label="Admin PIN" type="password" value={deletePinInput} onChange={e => setDeletePinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && confirmSeasonDelete()} placeholder="Enter PIN" />
              {deletePinError && <p className="text-red-400 text-sm mb-2">{deletePinError}</p>}
              <div className="flex gap-2">
                <Btn variant="danger" className="flex-1" onClick={confirmSeasonDelete}>Delete Season</Btn>
                <Btn variant="ghost" className="flex-1" onClick={() => setConfirmDeleteSeason(null)}>Cancel</Btn>
              </div>
            </Modal>
          )}
          {editSeason && (
            <Modal title="Edit Season" onClose={() => setEditSeason(null)}>
              <Input label="Season Name" value={editSeason.name} onChange={e => setEditSeason(s => ({ ...s, name: e.target.value }))} onKeyDown={e => e.key === 'Enter' && saveEditSeason()} placeholder="e.g. 2024/25" />
              <Sel label="Game Type" value={editSeason.type} onChange={e => setEditSeason(s => ({ ...s, type: e.target.value }))}>
                <option>League</option>
                <option>Cup</option>
              </Sel>
              <div className="flex gap-2 mt-1">
                <Btn onClick={saveEditSeason} className="flex-1">Save</Btn>
                <Btn variant="ghost" onClick={() => setEditSeason(null)} className="flex-1">Cancel</Btn>
              </div>
            </Modal>
          )}
        </div>
      )}

      {/* ── Data ── */}
      {section === 'data' && (
        <div className="space-y-4">
          <div className="bg-zinc-800 rounded-xl p-4">
            <h3 className="font-bold text-white text-sm mb-1">Export Backup</h3>
            <p className="text-zinc-400 text-xs mb-3">Download all your data as a JSON file.</p>
            <Btn className="w-full" onClick={handleExport}>⬇ Export JSON</Btn>
          </div>
          <div className="bg-zinc-800 rounded-xl p-4">
            <h3 className="font-bold text-white text-sm mb-1">Import Backup</h3>
            <p className="text-zinc-400 text-xs mb-3">Paste a previously exported JSON file to restore data. <strong className="text-amber-400">This overwrites all current data.</strong></p>
            <textarea value={importText} onChange={e => { setImportText(e.target.value); setImportError(''); setImportSuccess(false) }}
              placeholder="Paste JSON here..." rows={5}
              className="w-full bg-zinc-900 border border-zinc-600 rounded-lg px-3 py-2 text-white text-xs font-mono focus:outline-none focus:border-amber-500 mb-2 resize-none" />
            {importError   && <p className="text-red-400 text-xs mb-2">{importError}</p>}
            {importSuccess && <p className="text-emerald-400 text-xs mb-2">✓ Data imported successfully!</p>}
            <Btn variant="outline" className="w-full" onClick={handleImport} disabled={importing}>
              {importing ? 'Importing...' : '⬆ Import JSON'}
            </Btn>
          </div>
        </div>
      )}
    </div>
  )
}
