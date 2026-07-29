import { useRef, useState } from 'react'

const DRAG_CLOSE_THRESHOLD = 96

function MenuOption({ icon, title, description, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex min-h-16 w-full items-center gap-4 rounded-2xl border border-zinc-800 bg-zinc-900/80 px-3.5 py-3 text-left transition hover:border-amber-500/60 hover:bg-zinc-800 active:scale-[0.99]"
    >
      <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl border border-amber-500/30 bg-amber-500/10 text-2xl text-amber-300 shadow-[0_0_20px_rgba(251,191,36,0.08)]">
        <span aria-hidden="true">{icon}</span>
      </div>
      <div className="min-w-0">
        <p className="text-base font-bold text-white">{title}</p>
        <p className="mt-0.5 text-sm text-zinc-400">{description}</p>
      </div>
    </button>
  )
}

export default function SetupTab({
  onOpenProfile,
  onSwitchTeam,
  onManageTeam,
  onCreateTeam,
  canSwitchTeam,
  canManageTeam,
  onClose,
}) {
  const touchStartYRef = useRef(null)
  const [dragOffset, setDragOffset] = useState(0)
  const [isDragging, setIsDragging] = useState(false)

  const handleTouchStart = event => {
    touchStartYRef.current = event.touches[0]?.clientY ?? null
    setIsDragging(true)
  }

  const handleTouchMove = event => {
    if (touchStartYRef.current == null) return
    const currentY = event.touches[0]?.clientY ?? touchStartYRef.current
    const nextOffset = Math.max(0, currentY - touchStartYRef.current)
    setDragOffset(nextOffset)
  }

  const handleTouchEnd = () => {
    setIsDragging(false)
    if (dragOffset >= DRAG_CLOSE_THRESHOLD) {
      onClose()
      return
    }
    setDragOffset(0)
    touchStartYRef.current = null
  }

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/60 px-3 pb-24 pt-6 backdrop-blur-sm" onClick={onClose}>
      <div
        className="w-full max-w-lg rounded-[2rem] border border-zinc-800 bg-zinc-950/98 shadow-[0_-12px_40px_rgba(0,0,0,0.55)]"
        onClick={event => event.stopPropagation()}
        style={{
          transform: `translateY(${dragOffset}px)`,
          transition: isDragging ? 'none' : 'transform 180ms ease-out',
        }}
      >
        <div
          className="flex cursor-grab flex-col items-center px-5 pb-3 pt-3 active:cursor-grabbing"
          onTouchStart={handleTouchStart}
          onTouchMove={handleTouchMove}
          onTouchEnd={handleTouchEnd}
          onTouchCancel={handleTouchEnd}
        >
          <div className="h-1.5 w-28 rounded-full bg-zinc-700" />
        </div>

        <div className="px-5 pb-6">
          <div className="space-y-2">
            <MenuOption
              icon="👤"
              title="Profile"
              description="Open your account details and preferences."
              onClick={onOpenProfile}
            />
            {canSwitchTeam && (
              <MenuOption
                icon="🔄"
                title="Switch Team"
                description="Choose which team is active across the app."
                onClick={onSwitchTeam}
              />
            )}
            {canManageTeam && (
              <MenuOption
                icon="👥"
                title="Manage Team"
                description="Open settings for the currently active team."
                onClick={onManageTeam}
              />
            )}
            <MenuOption
              icon="➕"
              title="Create Team"
              description="Set up a new team and become its captain."
              onClick={onCreateTeam}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
