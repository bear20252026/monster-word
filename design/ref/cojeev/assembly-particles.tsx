"use client"

import * as React from "react"

import { useChoreography } from "@/lib/cojeev-motion/choreography"
import { useMotionVisibility } from "@/lib/cojeev-motion/use-motion-visibility"

type PartFrame = {
  x: number
  y: number
  width: number
  height: number
  rotation: number
}

export type AssemblyParticleSeed = {
  edge: number
  edgePosition: number
  phase: number
  orbit: number
  speed: number
}

export type AssemblyParticleMotion = {
  x: number
  y: number
  vx: number
  vy: number
  alpha: number
}

type Particle = AssemblyParticleSeed &
  AssemblyParticleMotion & {
    partId: string
    radius: number
    color: number
  }

const FALLBACK_PALETTE = ["#c98a9d", "#8c9568", "#7393a8", "#d9b85f"]

function hash(value: string) {
  let result = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    result ^= value.charCodeAt(index)
    result = Math.imul(result, 16777619)
  }
  return result >>> 0
}

function unit(value: string) {
  return hash(value) / 4294967295
}

export function assemblyParticleCount(count = 140, width = Infinity) {
  const bounded = Math.max(24, Math.min(200, Math.round(Number.isFinite(count) ? count : 140)))
  return width <= 480 ? Math.max(24, Math.round(bounded * 0.58)) : bounded
}

export function assemblyParticleSeed(partId: string, index: number): AssemblyParticleSeed {
  const key = partId + ":" + index
  return {
    edge: hash(key + ":edge") % 4,
    edgePosition: 0.08 + unit(key + ":position") * 0.84,
    phase: unit(key + ":phase") * Math.PI * 2,
    orbit: 8 + unit(key + ":orbit") * 22,
    speed: 0.16 + unit(key + ":speed") * 0.3,
  }
}

export function assemblyParticleTarget(
  seed: AssemblyParticleSeed,
  frame: PartFrame,
  time: number,
  gathered: boolean
) {
  const centerX = frame.x + frame.width / 2
  const centerY = frame.y + frame.height / 2
  let localX = 0
  let localY = 0

  if (gathered) {
    const across = (seed.edgePosition - 0.5) * (seed.edge % 2 ? frame.height : frame.width)
    const depth = seed.edge % 2 ? frame.width / 2 : frame.height / 2
    localX = seed.edge === 1 ? depth : seed.edge === 3 ? -depth : across
    localY = seed.edge === 2 ? depth : seed.edge === 0 ? -depth : across
  } else {
    const angle = seed.phase + time * seed.speed + (frame.rotation * Math.PI) / 180
    const breath = Math.sin(time * 0.9 + seed.phase) * 3
    localX = Math.cos(angle) * (frame.width * 0.54 + seed.orbit + breath)
    localY = Math.sin(angle) * (frame.height * 0.54 + seed.orbit * 0.7 + breath)
    return { x: centerX + localX, y: centerY + localY }
  }

  const rotation = (frame.rotation * Math.PI) / 180
  return {
    x: centerX + localX * Math.cos(rotation) - localY * Math.sin(rotation),
    y: centerY + localX * Math.sin(rotation) + localY * Math.cos(rotation),
  }
}

export function advanceAssemblyParticle(
  state: AssemblyParticleMotion,
  target: { x: number; y: number; alpha: number },
  dt: number,
  gathered: boolean
): AssemblyParticleMotion {
  const step = Math.max(0, Math.min(0.034, dt))
  const spring = gathered ? 34 : 14
  const damping = Math.exp(-(gathered ? 8.5 : 5) * step)
  const vx = (state.vx + (target.x - state.x) * spring * step) * damping
  const vy = (state.vy + (target.y - state.y) * spring * step) * damping
  const fade = Math.min(1, step * (gathered ? 5 : 3))
  return {
    x: state.x + vx * step,
    y: state.y + vy * step,
    vx,
    vy,
    alpha: state.alpha + (target.alpha - state.alpha) * fade,
  }
}

type AssemblyParticlesProps = {
  hostRef: React.RefObject<HTMLElement | null>
  assembled: boolean
  settled: boolean
  count?: number
  className?: string
}

type ParticleRuntime = {
  wake: () => void
  setPlaying: (playing: boolean, clear: boolean) => void
}

export function AssemblyParticles({
  hostRef,
  assembled,
  settled,
  count = 140,
  className,
}: AssemblyParticlesProps) {
  const canvasRef = React.useRef<HTMLCanvasElement>(null)
  const stateRef = React.useRef({ assembled, settled })
  const runtimeRef = React.useRef<ParticleRuntime | null>(null)
  const { enabled, inView } = useMotionVisibility(hostRef)
  const { quiet } = useChoreography()

  React.useLayoutEffect(() => {
    stateRef.current = { assembled, settled }
    runtimeRef.current?.wake()
  }, [assembled, settled])

  React.useEffect(() => {
    const host = hostRef.current
    const canvas = canvasRef.current
    const context = canvas?.getContext("2d")
    if (!host || !canvas || !context) return

    let width = 1
    let height = 1
    let playing = false
    let frameRequest = 0
    let previousTime = performance.now()
    let parts: Array<[string, HTMLElement]> = []
    const particles: Particle[] = []
    let palette = FALLBACK_PALETTE

    const refreshParts = () => {
      parts = Array.from(host.querySelectorAll<HTMLElement>(":scope > [data-assembly-part]"))
        .map((part) => [part.dataset.assemblyPart || "part", part] as [string, HTMLElement])
        .sort(([left], [right]) => left.localeCompare(right))
      particles.forEach((particle, index) => {
        const partId = parts[index % Math.max(1, parts.length)]?.[0] || "host"
        if (partId !== particle.partId) Object.assign(particle, assemblyParticleSeed(partId, index))
        particle.partId = partId
      })
    }

    const syncParticles = () => {
      const desired = assemblyParticleCount(count, width)
      if (particles.length > desired) particles.length = desired
      while (particles.length < desired) {
        const index = particles.length
        const partId = parts[index % Math.max(1, parts.length)]?.[0] || "host"
        const seed = assemblyParticleSeed(partId, index)
        particles.push({
          ...seed,
          partId,
          x: width / 2 + Math.cos(seed.phase) * seed.orbit,
          y: height / 2 + Math.sin(seed.phase) * seed.orbit,
          vx: Math.cos(seed.phase + Math.PI / 2) * 4,
          vy: Math.sin(seed.phase + Math.PI / 2) * 4,
          alpha: 0,
          radius: 0.7 + unit(partId + ":radius:" + index) * 1.5,
          color: hash(partId + ":color:" + index) % palette.length,
        })
      }
    }

    const readPalette = () => {
      const styles = getComputedStyle(host)
      const tokens = ["--v-pink", "--v-olive", "--v-blue", "--v-yellow"]
      palette = tokens.map((token, index) => styles.getPropertyValue(token).trim() || FALLBACK_PALETTE[index])
    }

    const resize = () => {
      width = Math.max(1, host.clientWidth)
      height = Math.max(1, host.clientHeight)
      const pixelRatio = Math.min(2, window.devicePixelRatio || 1)
      canvas.width = Math.round(width * pixelRatio)
      canvas.height = Math.round(height * pixelRatio)
      context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0)
      const previousCount = particles.length
      syncParticles()
      const initialFrames = readFrames()
      particles.slice(previousCount).forEach((particle) => {
        const partFrame = initialFrames.get(particle.partId)
        if (!partFrame) return
        const target = assemblyParticleTarget(particle, partFrame, performance.now() / 1000, false)
        particle.x = target.x
        particle.y = target.y
      })
    }

    const readFrames = () => {
      const frames = new Map<string, PartFrame>()
      parts.forEach(([id, part]) => {
        const x = Number.parseFloat(part.style.left)
        const y = Number.parseFloat(part.style.top)
        const partWidth = Number.parseFloat(part.style.width)
        const partHeight = Number.parseFloat(part.style.height)
        const rotation = Number.parseFloat(part.style.getPropertyValue("--assembly-rotation"))
        if ([x, y, partWidth, partHeight].every(Number.isFinite)) {
          frames.set(id, { x, y, width: partWidth, height: partHeight, rotation: rotation || 0 })
        }
      })
      return frames
    }

    const draw = (time: number) => {
      frameRequest = 0
      const dt = Math.min(0.034, Math.max(0, (time - previousTime) / 1000))
      previousTime = time
      const frames = readFrames()
      const gathered = stateRef.current.assembled
      const targetAlpha = gathered && stateRef.current.settled ? 0 : gathered ? 0.5 : 0.82
      let visible = false
      context.clearRect(0, 0, width, height)

      particles.forEach((particle) => {
        const partFrame = frames.get(particle.partId) || {
          x: width / 2,
          y: height / 2,
          width: 1,
          height: 1,
          rotation: 0,
        }
        const target = assemblyParticleTarget(particle, partFrame, time / 1000, gathered)
        Object.assign(
          particle,
          advanceAssemblyParticle(particle, { ...target, alpha: targetAlpha }, dt, gathered)
        )
        if (particle.alpha <= 0.006) return
        visible = true
        context.globalAlpha = particle.alpha
        context.fillStyle = palette[particle.color]
        context.beginPath()
        context.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2)
        context.fill()
      })
      context.globalAlpha = 1

      if (playing && (!(gathered && stateRef.current.settled) || visible)) {
        frameRequest = requestAnimationFrame(draw)
      }
    }

    const wake = () => {
      if (playing && !frameRequest) {
        previousTime = performance.now()
        frameRequest = requestAnimationFrame(draw)
      }
    }

    runtimeRef.current = {
      wake,
      setPlaying(nextPlaying, clear) {
        playing = nextPlaying
        if (!playing && frameRequest) cancelAnimationFrame(frameRequest)
        if (!playing) frameRequest = 0
        if (clear) context.clearRect(0, 0, width, height)
        if (playing) wake()
      },
    }

    refreshParts()
    readPalette()
    resize()
    const resizeObserver = new ResizeObserver(resize)
    const partObserver = new MutationObserver(() => {
      refreshParts()
      syncParticles()
      wake()
    })
    const themeObserver = new MutationObserver(() => {
      readPalette()
      wake()
    })
    resizeObserver.observe(host)
    partObserver.observe(host, { childList: true })
    themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-mode", "data-skin", "style"],
    })

    return () => {
      if (frameRequest) cancelAnimationFrame(frameRequest)
      resizeObserver.disconnect()
      partObserver.disconnect()
      themeObserver.disconnect()
      runtimeRef.current = null
    }
  }, [count, hostRef])

  React.useEffect(() => {
    runtimeRef.current?.setPlaying(enabled && inView && !quiet, quiet)
  }, [enabled, inView, quiet, count, hostRef])

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className={["v-assembly-particles", className].filter(Boolean).join(" ")}
      data-slot="assembly-particles"
      style={{ height: "100%", inset: 0, pointerEvents: "none", position: "absolute", width: "100%" }}
    />
  )
}
