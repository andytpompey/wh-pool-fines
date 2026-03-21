import { useRef, useState } from 'react'

const DRAG_CLOSE_THRESHOLD = 96

function MenuOption({ icon, title, description, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-4 rounded-2xl px-2 py-3 text-left transition hover:bg-zinc-100/70 active:scale-[0.99]"
    >
      <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-zinc-100 text-2xl text-zinc-800">
        <span aria-hidden="true">{icon}</span>
      </div>
      <div>
        <p className="text-lg font-semibold text-zinc-900">{title}</p>
        <p className="mt-0.5 text-sm text-zinc-500">{description}</p>
      </div>
    </button>
  )
}

export default function SetupTab({ onOpenProfile, onOpenTeams, onClose }) {
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
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/45 px-3 pb-24 pt-6 backdrop-blur-sm" onClick={onClose}>
      <div
        className="w-full max-w-lg rounded-[2rem] bg-white shadow-2xl"
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
          <div className="h-1.5 w-28 rounded-full bg-zinc-300" />
        </div>

        <div className="px-5 pb-6">
          <div className="space-y-2">
            <MenuOption
              icon="👤"
              title="Profile"
              description="Open your account details and preferences."
              onClick={onOpenProfile}
            />
            <MenuOption
              icon="👥"
              title="Team"
              description="Switch teams and open your current team view."
              onClick={onOpenTeams}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
