/**
 * CANDELA 2D - Game Engine
 * High-performance 2D Tactical Split-Screen Shooter
 * Pure HTML5 Canvas & Web Audio API (Vanilla JS)
 * V0.1
 */

// ==========================================
// 1. AUDIO ENGINE (Web Audio API Synthesizer)
// ==========================================
class AudioEngine {
    constructor() {
        this.ctx = null;
        this.isMuted = false;
    }

    init() {
        if (!this.ctx) {
            const AudioCtx = window.AudioContext || window.webkitAudioContext;
            this.ctx = new AudioCtx();
        }
        if (this.ctx.state === 'suspended') {
            this.ctx.resume();
        }
    }

    playShoot() {
        if (!this.ctx) return;
        const t = this.ctx.currentTime;

        // 1. Noise burst for gun powder bang
        const bufferSize = this.ctx.sampleRate * 0.15;
        const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (bufferSize * 0.2));
        }

        const noise = this.ctx.createBufferSource();
        noise.buffer = buffer;

        const noiseFilter = this.ctx.createBiquadFilter();
        noiseFilter.type = 'bandpass';
        noiseFilter.frequency.setValueAtTime(1200, t);
        noiseFilter.frequency.exponentialRampToValueAtTime(100, t + 0.15);

        const noiseGain = this.ctx.createGain();
        noiseGain.gain.setValueAtTime(0.8, t);
        noiseGain.gain.exponentialRampToValueAtTime(0.01, t + 0.15);

        noise.connect(noiseFilter);
        noiseFilter.connect(noiseGain);
        noiseGain.connect(this.ctx.destination);

        // 2. Punchy Sub-Bass Kick
        const osc = this.ctx.createOscillator();
        const oscGain = this.ctx.createGain();

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(180, t);
        osc.frequency.exponentialRampToValueAtTime(30, t + 0.18);

        oscGain.gain.setValueAtTime(0.9, t);
        oscGain.gain.exponentialRampToValueAtTime(0.01, t + 0.18);

        osc.connect(oscGain);
        oscGain.connect(this.ctx.destination);

        noise.start(t);
        osc.start(t);
        osc.stop(t + 0.18);
    }

    playTorchClick(isOn) {
        if (!this.ctx) return;
        const t = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(isOn ? 1400 : 700, t);
        osc.frequency.exponentialRampToValueAtTime(isOn ? 2200 : 400, t + 0.04);

        gain.gain.setValueAtTime(0.3, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.04);

        osc.connect(gain);
        gain.connect(this.ctx.destination);

        osc.start(t);
        osc.stop(t + 0.04);
    }

    playHit() {
        if (!this.ctx) return;
        const t = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(300, t);
        osc.frequency.linearRampToValueAtTime(60, t + 0.12);

        gain.gain.setValueAtTime(0.7, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.12);

        osc.connect(gain);
        gain.connect(this.ctx.destination);

        osc.start(t);
        osc.stop(t + 0.12);
    }

    playKill() {
        if (!this.ctx) return;
        const t = this.ctx.currentTime;
        const osc1 = this.ctx.createOscillator();
        const osc2 = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc1.type = 'square';
        osc2.type = 'sawtooth';

        osc1.frequency.setValueAtTime(523.25, t); // C5
        osc1.frequency.setValueAtTime(659.25, t + 0.1); // E5
        osc1.frequency.setValueAtTime(783.99, t + 0.2); // G5

        osc2.frequency.setValueAtTime(130.81, t);
        osc2.frequency.linearRampToValueAtTime(40, t + 0.4);

        gain.gain.setValueAtTime(0.5, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.45);

        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(this.ctx.destination);

        osc1.start(t);
        osc2.start(t);
        osc1.stop(t + 0.45);
        osc2.stop(t + 0.45);
    }

    playFootstep() {
        if (!this.ctx) return;
        const t = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(120 + Math.random() * 40, t);
        osc.frequency.exponentialRampToValueAtTime(40, t + 0.03);

        gain.gain.setValueAtTime(0.12, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.03);

        osc.connect(gain);
        gain.connect(this.ctx.destination);

        osc.start(t);
        osc.stop(t + 0.03);
    }

    playCooldownReady() {
        // Reload sound disabled
        return;
    }

    playAmbientDrone() {
        if (!this.ctx || this.droneNode) return;
        const t = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(55, t);
        gain.gain.setValueAtTime(0.03, t);

        const osc2 = this.ctx.createOscillator();
        osc2.type = 'sine';
        osc2.frequency.setValueAtTime(82.5, t);
        const gain2 = this.ctx.createGain();
        gain2.gain.setValueAtTime(0.015, t);

        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc2.connect(gain2);
        gain2.connect(this.ctx.destination);

        osc.start();
        osc2.start();
        this.droneNode = { osc, gain, osc2, gain2 };
    }

    stopAmbientDrone() {
        if (this.droneNode) {
            try {
                this.droneNode.osc.stop();
                this.droneNode.osc2.stop();
            } catch (e) { /* already stopped */ }
            this.droneNode = null;
        }
    }

    playHeartbeat() {
        if (!this.ctx) return;
        const t = this.ctx.currentTime;
        for (let i = 0; i < 2; i++) {
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sine';
            const offset = i * 0.15;
            osc.frequency.setValueAtTime(60, t + offset);
            osc.frequency.exponentialRampToValueAtTime(30, t + offset + 0.1);
            gain.gain.setValueAtTime(0.2, t + offset);
            gain.gain.exponentialRampToValueAtTime(0.001, t + offset + 0.15);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(t + offset);
            osc.stop(t + offset + 0.15);
        }
    }
}

// ==========================================
// 2. INPUT & GAMEPAD MANAGER
// ==========================================
class InputManager {
    constructor() {
        this.gamepads = [null, null];
        this.deadzone = 0.15;

        // Keyboard & Mouse State
        this.keys = {};
        this.mousePos = { x: 0, y: 0 };
        this.mouseButtons = { left: false, right: false };
        this.mouseActive = false;

        window.addEventListener('keydown', (e) => {
            if (e.code) this.keys[e.code] = true;
            if (e.key) this.keys[e.key.toLowerCase()] = true;
        });

        window.addEventListener('keyup', (e) => {
            if (e.code) this.keys[e.code] = false;
            if (e.key) this.keys[e.key.toLowerCase()] = false;
        });

        window.addEventListener('mousemove', (e) => {
            this.mousePos.x = e.clientX;
            this.mousePos.y = e.clientY;
            this.mouseActive = true;
        });

        window.addEventListener('mousedown', (e) => {
            if (e.button === 0) this.mouseButtons.left = true;
            if (e.button === 2) this.mouseButtons.right = true;
        });

        window.addEventListener('mouseup', (e) => {
            if (e.button === 0) this.mouseButtons.left = false;
            if (e.button === 2) this.mouseButtons.right = false;
        });

        window.addEventListener('contextmenu', e => e.preventDefault());

        window.addEventListener('gamepadconnected', (e) => {
            console.log('Gamepad connected:', e.gamepad.id, e.gamepad.index);
            this.update();
        });

        window.addEventListener('gamepaddisconnected', (e) => {
            console.log('Gamepad disconnected:', e.gamepad.id, e.gamepad.index);
            this.update();
        });
    }

    update() {
        const rawGps = navigator.getGamepads ? navigator.getGamepads() : (navigator.webkitGetGamepads ? navigator.webkitGetGamepads() : []);
        let validGps = [];
        if (rawGps) {
            for (let i = 0; i < rawGps.length; i++) {
                const gp = rawGps[i];
                if (gp && gp.connected !== false) {
                    validGps.push(gp);
                }
            }
        }
        this.gamepads[0] = validGps[0] || null;
        this.gamepads[1] = validGps[1] || null;
    }

    applyDeadzone(x, y) {
        const mag = Math.hypot(x, y);
        if (mag < this.deadzone) return { x: 0, y: 0 };
        const norm = (mag - this.deadzone) / (1 - this.deadzone);
        return { x: (x / mag) * norm, y: (y / mag) * norm };
    }

    getPlayerInput(playerIndex, playerPos, cameraViewport) {
        this.update();
        const gp = this.gamepads[playerIndex];

        let moveX = 0;
        let moveY = 0;
        let aimAngle = null;
        let shoot = false;
        let light = false;
        let sprint = false;

        // 1. GAMEPAD INPUT PROCESSING
        if (gp) {
            // Left Stick: Movement (axes 0, 1)
            const lStick = this.applyDeadzone(gp.axes[0] || 0, gp.axes[1] || 0);
            moveX = lStick.x;
            moveY = lStick.y;

            // Right Stick: 360° Aiming
            // Check standard axes [2, 3] and alternate non-standard mappings [3, 4] or [2, 5]
            let rx = 0, ry = 0;

            const rCandidate1 = this.applyDeadzone(gp.axes[2] || 0, gp.axes[3] || 0);
            if (Math.hypot(rCandidate1.x, rCandidate1.y) > 0.08) {
                rx = rCandidate1.x;
                ry = rCandidate1.y;
            } else if (gp.axes.length >= 5) {
                const rCandidate2 = this.applyDeadzone(gp.axes[3] || 0, gp.axes[4] || 0);
                if (Math.hypot(rCandidate2.x, rCandidate2.y) > 0.08) {
                    rx = rCandidate2.x;
                    ry = rCandidate2.y;
                } else if (gp.axes.length >= 6) {
                    const rCandidate3 = this.applyDeadzone(gp.axes[2] || 0, gp.axes[5] || 0);
                    if (Math.hypot(rCandidate3.x, rCandidate3.y) > 0.08) {
                        rx = rCandidate3.x;
                        ry = rCandidate3.y;
                    }
                }
            }

            if (Math.hypot(rx, ry) > 0.08) {
                aimAngle = Math.atan2(ry, rx);
                this.mouseActive = false; // Right stick overrides mouse
            }

            // Triggers: LT/L2 (Light), RT/R2 (Shoot)
            const ltVal = gp.buttons[6] ? (typeof gp.buttons[6] === 'object' ? gp.buttons[6].value : gp.buttons[6]) : 0;
            const rtVal = gp.buttons[7] ? (typeof gp.buttons[7] === 'object' ? gp.buttons[7].value : gp.buttons[7]) : 0;

            light = ltVal > 0.2 || (gp.buttons[4] && (gp.buttons[4].pressed || gp.buttons[4] === 1)); // LT or LB
            shoot = rtVal > 0.2 || (gp.buttons[5] && (gp.buttons[5].pressed || gp.buttons[5] === 1)); // RT or RB

            // Sprint: any face button [0,1,2,3]
            for (let i = 0; i < 4; i++) {
                if (gp.buttons[i] && (gp.buttons[i].pressed || gp.buttons[i] === 1)) {
                    sprint = true;
                    break;
                }
            }
        }

        // 2. KEYBOARD & MOUSE FALLBACK
        if (playerIndex === 0) {
            // Keyboard Movement for P1 (WASD / ZQSD for QWERTY & AZERTY)
            if (moveX === 0 && moveY === 0) {
                if (this.keys['KeyW'] || this.keys['KeyZ'] || this.keys['w'] || this.keys['z']) moveY -= 1;
                if (this.keys['KeyS'] || this.keys['s']) moveY += 1;
                if (this.keys['KeyA'] || this.keys['KeyQ'] || this.keys['a'] || this.keys['q']) moveX -= 1;
                if (this.keys['KeyD'] || this.keys['d']) moveX += 1;

                if (moveX !== 0 && moveY !== 0) {
                    const norm = 1 / Math.sqrt(2);
                    moveX *= norm;
                    moveY *= norm;
                }
            }

            // Mouse Aiming for P1 Viewport
            if (aimAngle === null && (this.mouseActive || !gp) && cameraViewport) {
                const mouseWorldX = this.mousePos.x - cameraViewport.x + cameraViewport.camX - cameraViewport.width / 2;
                const mouseWorldY = this.mousePos.y - cameraViewport.y + cameraViewport.camY - cameraViewport.height / 2;
                aimAngle = Math.atan2(mouseWorldY - playerPos.y, mouseWorldX - playerPos.x);
            }

            if (!gp) {
                if (this.mouseButtons.left || this.keys['KeyE'] || this.keys['e'] || this.keys['KeyF'] || this.keys['f']) shoot = true;
                if (this.mouseButtons.right || this.keys['Space'] || this.keys[' ']) light = true;
                if (this.keys['ShiftLeft']) sprint = true;
            }
        } else if (playerIndex === 1) {
            // P2 Keyboard Controls (Arrows + IJKL Aim + O/P/M)
            if (moveX === 0 && moveY === 0) {
                if (this.keys['ArrowUp']) moveY -= 1;
                if (this.keys['ArrowDown']) moveY += 1;
                if (this.keys['ArrowLeft']) moveX -= 1;
                if (this.keys['ArrowRight']) moveX += 1;

                if (moveX !== 0 && moveY !== 0) {
                    const norm = 1 / Math.sqrt(2);
                    moveX *= norm;
                    moveY *= norm;
                }
            }

            let aimX = 0, aimY = 0;
            if (this.keys['KeyI'] || this.keys['i']) aimY -= 1;
            if (this.keys['KeyK'] || this.keys['k']) aimY += 1;
            if (this.keys['KeyJ'] || this.keys['j']) aimX -= 1;
            if (this.keys['KeyL'] || this.keys['l']) aimX += 1;

            if (aimX !== 0 || aimY !== 0) {
                aimAngle = Math.atan2(aimY, aimX);
            }

            if (!gp) {
                if (this.keys['KeyO'] || this.keys['o'] || this.keys['Numpad0'] || this.keys['Numpad1'] || this.keys['Numpad4']) shoot = true;
                if (this.keys['KeyP'] || this.keys['p'] || this.keys['NumpadControl'] || this.keys['Numpad2'] || this.keys['Numpad5']) light = true;
                if (this.keys['KeyM'] || this.keys['m'] || this.keys['Semicolon'] || this.keys['ShiftRight']) sprint = true;
            }
        }

        return { moveX, moveY, aimAngle, shoot, light, sprint, hasGamepad: !!gp };
    }

    isSkipButtonHeld(playerIndex) {
        this.update();
        const gp = this.gamepads[playerIndex];

        if (gp && gp.buttons && gp.buttons[0]) {
            const btn = gp.buttons[0];
            const pressed = typeof btn === 'object' ? (btn.pressed || btn.value > 0.15) : (btn === 1);
            if (pressed) return true;
        }

        // Keyboard fallback: 'KeyX' or 'Space' or 'Enter'
        if (this.keys['KeyX'] || this.keys['Space'] || this.keys['Enter']) return true;

        return false;
    }

    isAnyButtonHeld(playerIndex) {
        this.update();
        const gp = this.gamepads[playerIndex];

        if (gp && gp.buttons) {
            for (let i = 0; i < gp.buttons.length; i++) {
                const btn = gp.buttons[i];
                const pressed = typeof btn === 'object' ? (btn.pressed || btn.value > 0.15) : (btn === 1);
                if (pressed) return true;
            }
        }

        // Keyboard fallbacks:
        if (playerIndex === 0) {
            if (this.keys['Space'] || this.keys['KeyW'] || this.keys['KeyZ'] || this.keys['KeyA'] || this.keys['KeyQ'] || this.keys['KeyS'] || this.keys['KeyD'] || this.keys['KeyE'] || this.keys['Enter']) return true;
        } else {
            if (this.keys['KeyO'] || this.keys['KeyP'] || this.keys['ArrowUp'] || this.keys['ArrowDown'] || this.keys['ArrowLeft'] || this.keys['ArrowRight'] || this.keys['Enter']) return true;
        }

        return false;
    }
}

// ==========================================
// 3. MAP & GEOMETRY (WALLS & RAYCASTING)
// ==========================================
class LineSegment {
    constructor(x1, y1, x2, y2) {
        this.p1 = { x: x1, y: y1 };
        this.p2 = { x: x2, y: y2 };
    }
}

class TacticalMap {
    constructor() {
        this.width = 1400;
        this.height = 1400;
        this.segments = [];
        this.obstacles = [];

        this.buildMap('SQUARE');
    }

    buildMap(mapType = 'SQUARE') {
        this.segments = [];
        this.obstacles = [];

        // Outer Boundary Square Arena Walls
        this.addWall(0, 0, this.width, 0);
        this.addWall(this.width, 0, this.width, this.height);
        this.addWall(this.width, this.height, 0, this.height);
        this.addWall(0, this.height, 0, 0);

        if (mapType === 'RANDOM') {
            this.generateProceduralCover();
        }
    }

    generateProceduralCover() {
        const cx = 700;
        const cy = 700;

        // Generate 1 to 2 additional decor elements (each element is symmetric for P1 and P2)
        const count = 1 + Math.floor(Math.random() * 2); // 1 or 2 decor groups

        for (let k = 0; k < count; k++) {
            const mode = Math.floor(Math.random() * 4);

            if (mode === 0) {
                // Central Square Obstacle / Pillar (Self-Symmetric)
                const size = 70 + Math.floor(Math.random() * 50);
                const offsetX = (Math.random() - 0.5) * 160;
                const offsetY = (Math.random() - 0.5) * 160;
                this.addRectObstacle(cx - size / 2 + offsetX, cy - size / 2 + offsetY, size, size);
                // Also add its 180° symmetric counterpart if not perfectly centered
                if (Math.abs(offsetX) > 10 || Math.abs(offsetY) > 10) {
                    this.addRectObstacle(cx - size / 2 - offsetX, cy - size / 2 - offsetY, size, size);
                }
            } else if (mode === 1) {
                // Symmetric Pair of Crates (1 for P1 side, 1 for P2 side)
                const rx = 250 + Math.floor(Math.random() * 320);
                const ry = 220 + Math.floor(Math.random() * 320);
                const w = 70 + Math.floor(Math.random() * 50);
                const h = 70 + Math.floor(Math.random() * 50);

                // P1 side crate
                this.addRectObstacle(rx, ry, w, h);
                // P2 side 180° rotationally symmetric twin crate
                this.addRectObstacle(this.width - rx - w, this.height - ry - h, w, h);
            } else if (mode === 2) {
                // Symmetric Pair of L-Walls (Rotated 180° across center)
                const rx = 300 + Math.floor(Math.random() * 260);
                const ry = 250 + Math.floor(Math.random() * 280);
                const len = 100 + Math.floor(Math.random() * 60);

                // P1 L-Wall
                this.addWall(rx, ry, rx + len, ry);
                this.addWall(rx, ry, rx, ry + len);

                // P2 Symmetric L-Wall
                this.addWall(this.width - rx - len, this.height - ry, this.width - rx, this.height - ry);
                this.addWall(this.width - rx, this.height - ry - len, this.width - rx, this.height - ry);
            } else {
                // Symmetric Pair of Straight Barrier Walls (Rotated 180°)
                const rx = 320 + Math.floor(Math.random() * 240);
                const ry = 200 + Math.floor(Math.random() * 340);
                const len = 110 + Math.floor(Math.random() * 70);
                const isHorizontal = Math.random() > 0.5;

                if (isHorizontal) {
                    this.addWall(rx, ry, rx + len, ry);
                    this.addWall(this.width - rx - len, this.height - ry, this.width - rx, this.height - ry);
                } else {
                    this.addWall(rx, ry, rx, ry + len);
                    this.addWall(this.width - rx, this.height - ry - len, this.width - rx, this.height - ry);
                }
            }
        }
    }

    addWall(x1, y1, x2, y2) {
        const seg = new LineSegment(x1, y1, x2, y2);
        this.segments.push(seg);
    }

    addRectObstacle(x, y, w, h) {
        this.obstacles.push({ x, y, w, h });
        this.addWall(x, y, x + w, y);
        this.addWall(x + w, y, x + w, y + h);
        this.addWall(x + w, y + h, x, y + h);
        this.addWall(x, y + h, x, y);
    }
}

// 2D Raycasting Engine for Light & Shadows
class RaycastEngine {
    static getIntersection(ray, segment) {
        const r_px = ray.a.x;
        const r_py = ray.a.y;
        const r_dx = ray.b.x - ray.a.x;
        const r_dy = ray.b.y - ray.a.y;

        const s_px = segment.p1.x;
        const s_py = segment.p1.y;
        const s_dx = segment.p2.x - segment.p1.x;
        const s_dy = segment.p2.y - segment.p1.y;

        const denom = r_dx * s_dy - r_dy * s_dx;
        if (Math.abs(denom) < 1e-9) {
            return null; // Parallel or collinear
        }

        const T1 = ((s_px - r_px) * s_dy - (s_py - r_py) * s_dx) / denom;
        const T2 = ((s_px - r_px) * r_dy - (s_py - r_py) * r_dx) / denom;

        if (T1 < 0) return null;
        if (T2 < 0 || T2 > 1) return null;

        return {
            x: r_px + r_dx * T1,
            y: r_py + r_dy * T1,
            param: T1
        };
    }

    static calculateVisibilityPolygon(sourceX, sourceY, maxRadius, segments, fovAngle = null, fovArc = null) {
        let points = [];
        for (let i = 0; i < segments.length; i++) {
            points.push(segments[i].p1);
            points.push(segments[i].p2);
        }

        let angles = [];
        for (let i = 0; i < points.length; i++) {
            const angle = Math.atan2(points[i].y - sourceY, points[i].x - sourceX);
            angles.push(angle - 0.0001, angle, angle + 0.0001);
        }

        // Add 30 fine-grained arc steps for a smooth spotlight curve
        if (fovAngle !== null && fovArc !== null) {
            const halfFov = fovArc / 2;
            const steps = 30;
            for (let i = 0; i <= steps; i++) {
                const rel = -halfFov + (i / steps) * fovArc;
                angles.push(fovAngle + rel);
            }
        }

        let rayResults = [];

        for (let i = 0; i < angles.length; i++) {
            const angle = angles[i];
            let relAngle = 0;

            if (fovAngle !== null && fovArc !== null) {
                let diff = angle - fovAngle;
                while (diff < -Math.PI) diff += Math.PI * 2;
                while (diff > Math.PI) diff -= Math.PI * 2;
                if (Math.abs(diff) > fovArc / 2 + 0.02) continue;
                relAngle = diff;
            }

            const dx = Math.cos(angle) * maxRadius;
            const dy = Math.sin(angle) * maxRadius;
            const ray = { a: { x: sourceX, y: sourceY }, b: { x: sourceX + dx, y: sourceY + dy } };

            let minParam = 1;
            let closestIntersect = null;

            for (let j = 0; j < segments.length; j++) {
                const intersect = RaycastEngine.getIntersection(ray, segments[j]);
                if (intersect && intersect.param < minParam) {
                    minParam = intersect.param;
                    closestIntersect = intersect;
                }
            }

            if (!closestIntersect) {
                closestIntersect = {
                    x: sourceX + dx,
                    y: sourceY + dy,
                    param: 1
                };
            }

            rayResults.push({
                x: closestIntersect.x,
                y: closestIntersect.y,
                angle: angle,
                relAngle: relAngle
            });
        }

        // SORT RAYS STRICTLY BY RELATIVE ANGLE TO PREVENT WRAP-AROUND DISCONTINUITIES & SPIKES
        if (fovAngle !== null) {
            rayResults.sort((a, b) => a.relAngle - b.relAngle);
        } else {
            rayResults.sort((a, b) => a.angle - b.angle);
        }

        // Form polygon starting from source origin (apex of pie slice)
        let poly = [{ x: sourceX, y: sourceY }];
        for (let i = 0; i < rayResults.length; i++) {
            poly.push({ x: rayResults[i].x, y: rayResults[i].y });
        }

        return poly;
    }

    static isPointInPolygon(px, py, polygon) {
        let inside = false;
        for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
            const xi = polygon[i].x, yi = polygon[i].y;
            const xj = polygon[j].x, yj = polygon[j].y;

            const intersect = ((yi > py) !== (yj > py)) &&
                (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
            if (intersect) inside = !inside;
        }
        return inside;
    }
}

// ==========================================
// 4. ENTITIES (PLAYER, BULLET, PARTICLES)
// ==========================================
class Player {
    constructor(id, name, color, startX, startY, startAngle) {
        this.id = id;
        this.name = name;
        this.color = color;
        this.x = startX;
        this.y = startY;
        this.vx = 0;
        this.vy = 0;
        this.radius = 18;
        this.angle = startAngle;
        this.hp = 100;
        this.score = 0;

        this.speed = 260; // px/sec
        this.flashlightOn = false;
        this.flashlightFov = Math.PI * 0.25; // ~45 degrees (narrower beam)
        this.flashlightRange = 750; // increased range

        this.shootCooldown = 0; // Cooldown timer (1.0s max)
        this.maxCooldown = 1.0;
        this.lastMuzzleFlash = 0; // Duration of light burst after firing

        this.footstepTimer = 0;
        this.screenShake = 0;
        this.ghostHp = 100;
        this.targetAngle = startAngle;
        this.punchZoom = 0;
        this.vignetteFlash = 0;
        this.dazzleAmount = 0; // 0 = clear vision, 1 = fully blinded
    }

    resetPosition(x, y, angle) {
        this.x = x;
        this.y = y;
        this.vx = 0;
        this.vy = 0;
        this.angle = angle;
        this.hp = 100;
        this.shootCooldown = 0;
        this.flashlightOn = false;
        this.lastMuzzleFlash = 0;
        this.ghostHp = 100;
        this.punchZoom = 0;
        this.vignetteFlash = 0;
        this.dazzleAmount = 0;
    }

    update(dt, input, mapSegments, audioEngine) {
        // Cooldown timer decrease
        if (this.shootCooldown > 0) {
            const prevCd = this.shootCooldown;
            this.shootCooldown -= dt;
            if (this.shootCooldown <= 0) {
                this.shootCooldown = 0;
            }
        }

        if (this.lastMuzzleFlash > 0) {
            this.lastMuzzleFlash -= dt;
        }

        if (this.screenShake > 0) {
            this.screenShake -= dt * 10;
            if (this.screenShake < 0) this.screenShake = 0;
        }

        // Sprint logic
        let currentSpeed = this.speed;
        let isMoving = input.moveX !== 0 || input.moveY !== 0;
        this.isSprinting = input.sprint && isMoving && this.hp > 0;

        if (this.isSprinting) {
            currentSpeed *= 2;
            this.flashlightOn = false; // Disable light while sprinting
        } else if (!input.sprint) {
            // Only allow toggling light when sprint button is NOT held
            this.flashlightOn = input.light && this.hp > 0;
        } else {
            // Sprint held but not moving: still block the light
            this.flashlightOn = false;
        }

        // Dazzle decay (fades 4x faster when no longer illuminated)
        if (this.dazzleAmount > 0) {
            this.dazzleAmount = Math.max(0, this.dazzleAmount - dt * 10.0);
        }

        // Movement (20% slower when fully dazzled)
        const dazzleSpeedPenalty = 1.0 - this.dazzleAmount * 0.2;
        this.vx = input.moveX * currentSpeed * dazzleSpeedPenalty;
        this.vy = input.moveY * currentSpeed * dazzleSpeedPenalty;

        // Apply movement physics with wall collision
        const nextX = this.x + this.vx * dt;
        const nextY = this.y + this.vy * dt;

        this.moveAndCollide(nextX, nextY, mapSegments);

        // Aim angle update (smooth lerp — 60% slower when fully dazzled)
        if (input.aimAngle !== null) {
            this.targetAngle = input.aimAngle;
        }
        let angleDiff = this.targetAngle - this.angle;
        while (angleDiff < -Math.PI) angleDiff += Math.PI * 2;
        while (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
        const aimLerpSpeed = 18 * (1.0 - this.dazzleAmount * 0.6);
        this.angle += angleDiff * Math.min(1, dt * aimLerpSpeed);

        // Flashlight toggle (only if not sprint-blocked)
        if (!this.isSprinting && !input.sprint && input.light !== this.flashlightOn) {
            this.flashlightOn = input.light;
            audioEngine.playTorchClick(this.flashlightOn);
        }

        // Footstep sound feedback
        if (Math.hypot(this.vx, this.vy) > 20) {
            this.footstepTimer += dt;
            if (this.footstepTimer > 0.32) {
                this.footstepTimer = 0;
                audioEngine.playFootstep();
            }
        } else {
            this.footstepTimer = 0;
        }

        // Ghost HP lerp (delayed health bar)
        if (this.ghostHp > this.hp) {
            this.ghostHp -= dt * 60;
            if (this.ghostHp < this.hp) this.ghostHp = this.hp;
        } else {
            this.ghostHp = this.hp;
        }

        // Punch zoom decay
        if (this.punchZoom > 0) {
            this.punchZoom -= dt * 12;
            if (this.punchZoom < 0) this.punchZoom = 0;
        }

        // Vignette flash decay
        if (this.vignetteFlash > 0) {
            this.vignetteFlash -= dt * 5;
            if (this.vignetteFlash < 0) this.vignetteFlash = 0;
        }
    }

    moveAndCollide(targetX, targetY, segments) {
        let finalX = targetX;
        let finalY = targetY;

        for (let i = 0; i < segments.length; i++) {
            const seg = segments[i];
            const closest = this.getClosestPointOnSegment(finalX, finalY, seg.p1, seg.p2);
            const dist = Math.hypot(finalX - closest.x, finalY - closest.y);

            if (dist < this.radius) {
                const overlap = this.radius - dist;
                const nx = dist > 0 ? (finalX - closest.x) / dist : 1;
                const ny = dist > 0 ? (finalY - closest.y) / dist : 0;

                finalX += nx * overlap;
                finalY += ny * overlap;
            }
        }

        this.x = finalX;
        this.y = finalY;
    }

    getClosestPointOnSegment(px, py, p1, p2) {
        const dx = p2.x - p1.x;
        const dy = p2.y - p1.y;
        const lenSq = dx * dx + dy * dy;

        if (lenSq === 0) return { x: p1.x, y: p1.y };

        let t = ((px - p1.x) * dx + (py - p1.y) * dy) / lenSq;
        t = Math.max(0, Math.min(1, t));

        return { x: p1.x + t * dx, y: p1.y + t * dy };
    }
}

class Bullet {
    constructor(x, y, angle, ownerId) {
        this.x = x;
        this.y = y;
        this.speed = 1800; // Ultra-fast tactical projectile
        this.vx = Math.cos(angle) * this.speed;
        this.vy = Math.sin(angle) * this.speed;
        this.ownerId = ownerId;
        this.radius = 5;
        this.distanceTraveled = 0;
        this.maxDistance = 10000; // Infinite range across map
        this.alive = true;
    }

    getClosestPointOnSegment(px, py, p1, p2) {
        const dx = p2.x - p1.x;
        const dy = p2.y - p1.y;
        const lenSq = dx * dx + dy * dy;
        if (lenSq === 0) return { x: p1.x, y: p1.y };
        let t = ((px - p1.x) * dx + (py - p1.y) * dy) / lenSq;
        t = Math.max(0, Math.min(1, t));
        return { x: p1.x + t * dx, y: p1.y + t * dy };
    }

    update(dt, segments, players, particles, audioEngine) {
        if (!this.alive) return;

        const nextX = this.x + this.vx * dt;
        const nextY = this.y + this.vy * dt;
        const travelStep = Math.hypot(nextX - this.x, nextY - this.y);

        this.distanceTraveled += travelStep;
        if (this.distanceTraveled >= this.maxDistance) {
            this.alive = false;
            return;
        }

        // 1. Continuous collision check with players FIRST (Thick & generous 43px Hitbox!)
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (p.id === this.ownerId || p.hp <= 0) continue;

            const closest = this.getClosestPointOnSegment(p.x, p.y, { x: this.x, y: this.y }, { x: nextX, y: nextY });
            const dist = Math.hypot(p.x - closest.x, p.y - closest.y);

            const thickHitboxRadius = p.radius + this.radius + 20; // ~43px generous hit zone
            if (dist <= thickHitboxRadius) {
                this.alive = false;
                p.hp -= 50; // 2 shots to kill
                p.screenShake = 1.0;
                p.punchZoom = 1.0;
                p.vignetteFlash = 1.0;
                audioEngine.playHit();

                // Find shooter & award points!
                const shooter = players.find(pl => pl.id === this.ownerId);
                if (shooter) {
                    shooter.score += 100;
                    particles.addFloatingText(closest.x, closest.y - 15, '+100 TOUCHÉ !', shooter.color);

                    if (p.hp <= 0) {
                        shooter.score += 500;
                        particles.addFloatingText(closest.x, closest.y - 35, '+500 ÉLIMINATION !', '#00ff88');
                    }
                }

                // Hit blood/energy spark particles
                for (let k = 0; k < 14; k++) {
                    particles.addBloodSpark(p.x, p.y, Math.atan2(this.vy, this.vx));
                }
                return;
            }
        }

        // 2. Ray collision check with wall segments SECOND!
        const ray = { a: { x: this.x, y: this.y }, b: { x: nextX, y: nextY } };
        let hitWall = false;

        for (let i = 0; i < segments.length; i++) {
            const intersect = RaycastEngine.getIntersection(ray, segments[i]);
            if (intersect) {
                this.x = intersect.x;
                this.y = intersect.y;
                this.alive = false;
                hitWall = true;

                // Spark particles on wall impact
                for (let k = 0; k < 8; k++) {
                    particles.addSpark(this.x, this.y, Math.atan2(-this.vy, -this.vx) + (Math.random() - 0.5));
                }
                break;
            }
        }

        if (hitWall) return;

        this.x = nextX;
        this.y = nextY;
        particles.addBulletTrail(this.x, this.y);
    }
}

class ParticleSystem {
    constructor() {
        this.particles = [];
    }

    addSpark(x, y, baseAngle) {
        const angle = baseAngle + (Math.random() - 0.5) * 1.2;
        const speed = 100 + Math.random() * 200;
        this.particles.push({
            x, y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 1.0,
            decay: 3.5 + Math.random() * 2,
            size: 2 + Math.random() * 2,
            color: '#ffc800'
        });
    }

    addBloodSpark(x, y, baseAngle) {
        const angle = baseAngle + (Math.random() - 0.5) * 0.8;
        const speed = 80 + Math.random() * 150;
        this.particles.push({
            x, y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 1.0,
            decay: 2.0 + Math.random() * 2,
            size: 3 + Math.random() * 2,
            color: '#ff0044'
        });
    }

    addBulletTrail(x, y) {
        this.particles.push({
            x, y,
            vx: 0, vy: 0,
            life: 1.0,
            decay: 10.0,
            size: 2,
            color: 'rgba(255, 230, 150, 0.4)'
        });
    }

    addBulletTracer(x1, y1, x2, y2, color) {
        const dx = x2 - x1;
        const dy = y2 - y1;
        const dist = Math.hypot(dx, dy) || 1; // Prevent div by 0

        this.particles.push({
            x1: x1, y1: y1,
            x2: x2, y2: y2,
            dx: dx / dist,
            dy: dy / dist,
            totalDist: dist,
            progress: 0.0,
            speed: 25.0, // Tracer speed multiplier
            tailLength: 180, // Length of the segment in px
            color: color,
            isBulletTracer: true,
            life: 1.0
        });
    }

    addFloatingText(x, y, text, color) {
        this.particles.push({
            x: x,
            y: y,
            vx: (Math.random() - 0.5) * 20,
            vy: -50,
            life: 1.0,
            decay: 1.2,
            text: text,
            color: color,
            isText: true
        });
    }

    update(dt) {
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const p = this.particles[i];

            if (p.isBulletTracer) {
                p.progress += p.speed * dt;
                const maxProgress = 1.0 + (p.tailLength / p.totalDist);
                if (p.progress >= maxProgress) {
                    this.particles.splice(i, 1);
                }
            } else {
                p.x = (p.x || 0) + (p.vx || 0) * dt;
                p.y = (p.y || 0) + (p.vy || 0) * dt;
                p.life -= p.decay * dt;
                if (p.life <= 0) {
                    this.particles.splice(i, 1);
                }
            }
        }
    }

    draw(ctx) {
        for (let i = 0; i < this.particles.length; i++) {
            const p = this.particles[i];
            ctx.globalAlpha = Math.max(0, p.life);

            if (p.isBulletTracer) {
                ctx.save();
                ctx.strokeStyle = p.color;
                ctx.lineWidth = 4;
                ctx.shadowColor = p.color;
                ctx.shadowBlur = 12;
                ctx.lineCap = 'round';

                const headDist = Math.min(p.totalDist, p.progress * p.totalDist);
                const tailDist = Math.max(0, p.progress * p.totalDist - p.tailLength);

                if (headDist > tailDist) {
                    const hx = p.x1 + p.dx * headDist;
                    const hy = p.y1 + p.dy * headDist;
                    const tx = p.x1 + p.dx * tailDist;
                    const ty = p.y1 + p.dy * tailDist;

                    ctx.beginPath();
                    ctx.moveTo(tx, ty);
                    ctx.lineTo(hx, hy);
                    ctx.stroke();

                    // Inner white core
                    ctx.strokeStyle = '#ffffff';
                    ctx.lineWidth = 2;
                    ctx.shadowBlur = 0;
                    ctx.stroke();
                }
                ctx.restore();
            } else if (p.isText) {
                ctx.save();
                ctx.font = 'bold 15px Orbitron, sans-serif';
                ctx.fillStyle = p.color;
                ctx.shadowColor = p.color;
                ctx.shadowBlur = 8;
                ctx.textAlign = 'center';
                ctx.fillText(p.text, p.x, p.y);
                ctx.restore();
            } else {
                ctx.fillStyle = p.color;
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
                ctx.fill();
            }
        }
        ctx.globalAlpha = 1.0;
    }
}

// Ambient Dust/Ember Particles
class AmbientParticleSystem {
    constructor(mapWidth, mapHeight) {
        this.particles = [];
        this.mapWidth = mapWidth || 1400;
        this.mapHeight = mapHeight || 1400;
        for (let i = 0; i < 60; i++) {
            this.particles.push(this.createParticle());
        }
    }

    createParticle() {
        return {
            x: Math.random() * this.mapWidth,
            y: Math.random() * this.mapHeight,
            vx: (Math.random() - 0.5) * 15,
            vy: -5 - Math.random() * 10,
            size: 1 + Math.random() * 2,
            alpha: 0.1 + Math.random() * 0.3,
            pulse: Math.random() * Math.PI * 2,
            pulseSpeed: 1 + Math.random() * 2,
            life: 1.0,
            maxLife: 8 + Math.random() * 12
        };
    }

    update(dt) {
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const p = this.particles[i];
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.pulse += p.pulseSpeed * dt;
            p.life -= dt / p.maxLife;
            if (p.life <= 0 || p.x < -20 || p.x > this.mapWidth + 20 || p.y < -20 || p.y > this.mapHeight + 20) {
                this.particles[i] = this.createParticle();
            }
        }
    }

    draw(ctx) {
        for (let i = 0; i < this.particles.length; i++) {
            const p = this.particles[i];
            const a = p.alpha * (0.5 + 0.5 * Math.sin(p.pulse)) * Math.min(1, p.life * 3);
            ctx.globalAlpha = a;
            ctx.fillStyle = '#ffeedd';
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            ctx.fill();
        }
        ctx.globalAlpha = 1.0;
    }
}

// ==========================================
// Replay System for Killcam
// ==========================================
class ReplaySystem {
    constructor(maxDuration = 2.0, fps = 60) {
        this.maxFrames = Math.ceil(maxDuration * fps);
        this.frames = [];
        this.frameTimer = 0;
        this.timePerFrame = 1 / fps;
    }

    reset() {
        this.frames = [];
        this.frameTimer = 0;
    }

    recordFrame(dt, game) {
        this.frameTimer += dt;
        if (this.frameTimer >= this.timePerFrame) {
            this.frameTimer = 0;
            const snapshot = {
                players: game.players.map(p => ({
                    id: p.id, name: p.name, color: p.color, radius: p.radius,
                    x: p.x, y: p.y, angle: p.angle, hp: p.hp,
                    flashlightOn: p.flashlightOn, lastMuzzleFlash: p.lastMuzzleFlash,
                    flashlightRange: p.flashlightRange, flashlightFov: p.flashlightFov,
                    screenShake: p.screenShake, punchZoom: p.punchZoom, vignetteFlash: p.vignetteFlash
                })),
                bullets: game.bullets.map(b => ({
                    x: b.x, y: b.y, radius: b.radius
                })),
                particles: game.particleSystem.particles.map(p => ({ ...p }))
            };
            this.frames.push(snapshot);
            if (this.frames.length > this.maxFrames) {
                this.frames.shift();
            }
        }
    }
}

// ==========================================
// 5. MAIN GAME CLASS & SPLIT-SCREEN RENDERER
// ==========================================
class CandelaGame {
    constructor() {
        this.canvas = document.getElementById('gameCanvas');
        this.ctx = this.canvas.getContext('2d');

        this.audioEngine = new AudioEngine();
        this.inputManager = new InputManager();
        this.map = new TacticalMap();
        this.particleSystem = new ParticleSystem();

        // Spawn Players
        this.players = [
            new Player(0, 'JOUEUR 1', '#00f0ff', 200, 200, Math.PI * 0.25),
            new Player(1, 'JOUEUR 2', '#ff0055', 1200, 1200, Math.PI * 1.25)
        ];

        this.bullets = [];
        this.roundTimer = 120; // 2 minutes
        this.currentRound = 1;
        this.gameState = 'START'; // START, PLAYING, VICTORY

        this.selectedMapType = 'SQUARE'; // Default map: open square room!
        this.p1Ready = false;
        this.p2Ready = false;
        this.p1HoldTimer = 0;
        this.p2HoldTimer = 0;
        this.requiredHoldTime = 0.5; // 0.5s hold duration!

        // Start Menu Hold Timers & States
        this.startP1Ready = false;
        this.startP2Ready = false;
        this.startP1HoldTimer = 0;
        this.startP2HoldTimer = 0;

        // Dual Virtual Cursors for Controller Menu Navigation
        this.p1Cursor = { x: window.innerWidth * 0.35, y: window.innerHeight * 0.5 };
        this.p2Cursor = { x: window.innerWidth * 0.65, y: window.innerHeight * 0.5 };
        this.cursorSpeed = 950; // px/sec
        this.p1ClickPrev = false;
        this.p2ClickPrev = false;

        this.lastTime = performance.now();

        // Polish systems
        this.ambientParticles = new AmbientParticleSystem(this.map.width, this.map.height);
        this.fogCanvas = null;
        this.fogCtx = null;
        this.cam = [
            { x: 200, y: 200 },
            { x: 1200, y: 1200 }
        ];
        this.camLerpSpeed = 8.0;
        this.bulletDecals = [];
        this.killFeedEntries = [];
        this.roundFadeIn = 0;
        this.slowMotionTimer = 0;
        this.scoreAnimP1 = 0;
        this.scoreAnimP2 = 0;
        this.prevScoreP1 = 0;
        this.prevScoreP2 = 0;
        this.heartbeatTimer = 0;

        // Replay System
        this.replaySystem = new ReplaySystem(2.5, 60); // 2.5 seconds of replay
        this.replayTimer = 0;
        this.currentReplaySnapshot = null;

        this.setupUI();
        this.resize();
        window.addEventListener('resize', () => this.resize());

        // Kick off Game Loop
        requestAnimationFrame((t) => this.loop(t));
    }

    setupUI() {
        const btnStart = document.getElementById('btn-start');
        if (btnStart) {
            btnStart.addEventListener('click', () => {
                this.startGameFromStartMenu();
            });
        }

        // Map choice button handlers
        const btnKeep = document.getElementById('btn-keep-map');
        const btnNew = document.getElementById('btn-new-map');

        if (btnKeep && btnNew) {
            btnKeep.addEventListener('click', () => {
                this.selectedMapType = 'SQUARE';
                btnKeep.classList.add('active');
                btnNew.classList.remove('active');
                this.audioEngine.playTorchClick(true);
            });

            btnNew.addEventListener('click', () => {
                this.selectedMapType = 'RANDOM';
                btnNew.classList.add('active');
                btnKeep.classList.remove('active');
                this.audioEngine.playTorchClick(true);
            });
        }

        const btnNext = document.getElementById('btn-next-round');
        if (btnNext) {
            btnNext.addEventListener('click', () => {
                this.startNextRound();
            });
        }
    }

    startGameFromStartMenu() {
        this.audioEngine.init();
        document.getElementById('start-overlay').classList.add('hidden');
        this.gameState = 'PLAYING';
        this.resetRound();
    }

    startNextRound() {
        document.getElementById('victory-modal').classList.add('hidden');
        this.currentRound++;
        this.map.buildMap(this.selectedMapType);
        this.resetRound();
        this.gameState = 'PLAYING';
    }

    resize() {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
    }

    resetRound() {
        this.players[0].resetPosition(200, 200, Math.PI * 0.25);
        this.players[1].resetPosition(1200, 1200, Math.PI * 1.25);
        this.bullets = [];
        this.roundTimer = 120;
        this.bulletDecals = [];
        this.roundFadeIn = 1.0;
        this.slowMotionTimer = 0;
        this.cam[0] = { x: 200, y: 200 };
        this.cam[1] = { x: 1200, y: 1200 };

        this.replaySystem.reset();
        this.replayTimer = 0;
        this.currentReplaySnapshot = null;

        // Start ambient drone
        this.audioEngine.playAmbientDrone();

        // Hide virtual cursors when round starts
        const elP1Cursor = document.getElementById('cursor-p1');
        const elP2Cursor = document.getElementById('cursor-p2');
        if (elP1Cursor) elP1Cursor.classList.add('hidden');
        if (elP2Cursor) elP2Cursor.classList.add('hidden');
    }

    shootGun(player) {
        if (player.shootCooldown > 0) return;

        player.shootCooldown = player.maxCooldown;
        player.lastMuzzleFlash = 2.5; // 2.5s light decay curve after firing
        player.screenShake = 0.8;

        const barrelOffset = player.radius + 10;
        const startX = player.x + Math.cos(player.angle) * barrelOffset;
        const startY = player.y + Math.sin(player.angle) * barrelOffset;

        // Cast ray across entire map in direction player.angle (up to 3500px)
        const maxDist = 3500;
        const endX = startX + Math.cos(player.angle) * maxDist;
        const endY = startY + Math.sin(player.angle) * maxDist;
        const fullRay = { a: { x: startX, y: startY }, b: { x: endX, y: endY } };

        // 1. Find Wall Intersection Point
        let wallHitPoint = { x: endX, y: endY };
        let minWallParam = 1.0;

        for (let i = 0; i < this.map.segments.length; i++) {
            const intersect = RaycastEngine.getIntersection(fullRay, this.map.segments[i]);
            if (intersect && intersect.param < minWallParam) {
                minWallParam = intersect.param;
                wallHitPoint = { x: intersect.x, y: intersect.y };
            }
        }

        const shotSegment = { p1: { x: startX, y: startY }, p2: wallHitPoint };

        let hitOpponent = null;
        let minOppDist = Infinity;
        let oppImpactPoint = null;
        let oppHitDamage = 0;

        for (let i = 0; i < this.players.length; i++) {
            const target = this.players[i];
            if (target.id === player.id || target.hp <= 0) continue;

            const closest = player.getClosestPointOnSegment(target.x, target.y, shotSegment.p1, shotSegment.p2);
            const dist = Math.hypot(target.x - closest.x, target.y - closest.y);

            const playerHitbox = target.radius * 1.2; // 1.2x enlarged player hitbox
            if (dist <= playerHitbox) {
                const distFromBarrel = Math.hypot(closest.x - startX, closest.y - startY);
                if (distFromBarrel < minOppDist) {
                    minOppDist = distFromBarrel;
                    hitOpponent = target;
                    oppImpactPoint = closest;

                    // Damage falloff: 100% at center, 25% at extreme edge of player radius.
                    // Cubic falloff ensures it stays high near center then drops sharply towards the edge.
                    const normalizedDist = dist / playerHitbox;
                    const multiplier = 0.25 + 0.75 * (1 - Math.pow(normalizedDist, 3));
                    oppHitDamage = Math.floor(50 * multiplier);
                }
            }
        }

        let finalImpactX = wallHitPoint.x;
        let finalImpactY = wallHitPoint.y;

        if (hitOpponent && oppImpactPoint) {
            finalImpactX = oppImpactPoint.x;
            finalImpactY = oppImpactPoint.y;

            // Apply Damage & Score!
            hitOpponent.hp -= oppHitDamage;
            hitOpponent.screenShake = 1.0;
            hitOpponent.punchZoom = 1.0;
            hitOpponent.vignetteFlash = 1.0;
            this.audioEngine.playHit();

            const scoreGain = Math.max(10, oppHitDamage * 2);
            player.score += scoreGain;

            // Show damage as floating text
            let damageText = `-${oppHitDamage} HP`;
            if (oppHitDamage >= 45) damageText = `CRITIQUE -${oppHitDamage}`;
            else if (oppHitDamage <= 20) damageText = `ÉRAFLURE -${oppHitDamage}`;

            this.particleSystem.addFloatingText(oppImpactPoint.x, oppImpactPoint.y - 15, damageText, player.color);
            this.addKillFeedEntry(`${player.name} → ${damageText}`, player.color);

            if (hitOpponent.hp <= 0) {
                player.score += 500;
                this.particleSystem.addFloatingText(oppImpactPoint.x, oppImpactPoint.y - 35, '+500 ÉLIMINATION !', '#00ff88');
                this.addKillFeedEntry(`${player.name} ✦ ÉLIMINATION !`, '#00ff88');
            }

            // Blood / Energy impact sparks
            for (let k = 0; k < 14; k++) {
                this.particleSystem.addBloodSpark(oppImpactPoint.x, oppImpactPoint.y, player.angle);
            }
        } else {
            // Wall impact sparks
            for (let k = 0; k < 8; k++) {
                this.particleSystem.addSpark(wallHitPoint.x, wallHitPoint.y, player.angle + Math.PI);
            }
            // Bullet decal on wall
            this.bulletDecals.push({ x: wallHitPoint.x, y: wallHitPoint.y, size: 3 + Math.random() * 4, alpha: 0.6 });
            if (this.bulletDecals.length > 50) this.bulletDecals.shift();
        }

        // Add visual fast tracer
        this.particleSystem.addBulletTracer(startX, startY, finalImpactX, finalImpactY, player.color);

        this.audioEngine.playShoot();
    }

    updateDazzle(target, illuminator, dt) {
        if (!illuminator.flashlightOn || illuminator.hp <= 0 || target.hp <= 0) return;

        const dist = Math.hypot(target.x - illuminator.x, target.y - illuminator.y);
        if (dist > illuminator.flashlightRange) return;

        // Is the target inside the illuminator's flashlight cone?
        const angleToTarget = Math.atan2(target.y - illuminator.y, target.x - illuminator.x);
        let diff = angleToTarget - illuminator.angle;
        while (diff < -Math.PI) diff += Math.PI * 2;
        while (diff > Math.PI) diff -= Math.PI * 2;

        if (Math.abs(diff) > illuminator.flashlightFov / 2) return;

        // Line-of-sight check (walls block the dazzle)
        const losRay = { a: { x: illuminator.x, y: illuminator.y }, b: { x: target.x, y: target.y } };
        for (let i = 0; i < this.map.segments.length; i++) {
            const intersect = RaycastEngine.getIntersection(losRay, this.map.segments[i]);
            if (intersect && intersect.param > 0.02 && intersect.param < 0.98) {
                return; // Wall blocks the beam
            }
        }

        // Dazzle intensity: stronger when closer and more centered in cone
        const distFactor = 1.0 - (dist / illuminator.flashlightRange);
        const angleFactor = 1.0 - (Math.abs(diff) / (illuminator.flashlightFov / 2));
        const intensity = distFactor * angleFactor;

        // Ramp up dazzle 4x faster (~0.025s to full) and store who is blinding us
        target.dazzleAmount = Math.min(1.0, target.dazzleAmount + intensity * dt * 64.0);
        target.dazzleSourceX = illuminator.x;
        target.dazzleSourceY = illuminator.y;
        target.dazzleSourceAngle = illuminator.angle;
    }

    updateMenuCursors(dt) {
        if (this.gameState !== 'VICTORY') return;

        const inP1 = this.inputManager.getPlayerInput(0, this.players[0], null);
        const inP2 = this.inputManager.getPlayerInput(1, this.players[1], null);

        const btnKeep = document.getElementById('btn-keep-map');
        const btnNew = document.getElementById('btn-new-map');
        if (!btnKeep || !btnNew) return;

        // Either player moving left or right toggles between map choices
        const moveX = inP1.moveX || inP2.moveX;
        if (!this.navCooldown) this.navCooldown = 0;
        if (this.navCooldown > 0) this.navCooldown -= dt;

        if (this.navCooldown <= 0) {
            if (moveX < -0.4 && this.selectedMapType !== 'SQUARE') {
                this.selectedMapType = 'SQUARE';
                btnKeep.classList.add('active');
                btnNew.classList.remove('active');
                this.audioEngine.playTorchClick(true);
                this.navCooldown = 0.25;
            } else if (moveX > 0.4 && this.selectedMapType !== 'RANDOM') {
                this.selectedMapType = 'RANDOM';
                btnNew.classList.add('active');
                btnKeep.classList.remove('active');
                this.audioEngine.playTorchClick(true);
                this.navCooldown = 0.25;
            }
        }
    }

    updateStartReadyLoop(dt) {
        // Player 1 Hold Detection
        if (this.inputManager.isAnyButtonHeld(0)) {
            this.startP1HoldTimer += dt;
        } else if (!this.startP1Ready) {
            this.startP1HoldTimer = Math.max(0, this.startP1HoldTimer - dt * 2.5);
        }

        const p1Prog = Math.min(1.0, this.startP1HoldTimer / this.requiredHoldTime);
        if (p1Prog >= 1.0 && !this.startP1Ready) {
            this.startP1Ready = true;
            this.audioEngine.playTorchClick(true);
        }
        this.updateStartReadyUI(0, this.startP1Ready, p1Prog);

        // Player 2 Hold Detection
        if (this.inputManager.isAnyButtonHeld(1)) {
            this.startP2HoldTimer += dt;
        } else if (!this.startP2Ready) {
            this.startP2HoldTimer = Math.max(0, this.startP2HoldTimer - dt * 2.5);
        }

        const p2Prog = Math.min(1.0, this.startP2HoldTimer / this.requiredHoldTime);
        if (p2Prog >= 1.0 && !this.startP2Ready) {
            this.startP2Ready = true;
            this.audioEngine.playTorchClick(true);
        }
        this.updateStartReadyUI(1, this.startP2Ready, p2Prog);

        if (this.startP1Ready && this.startP2Ready) {
            this.startGameFromStartMenu();
        }
    }

    updateStartReadyUI(playerIndex, isReady, progress = 0) {
        const badgeId = playerIndex === 0 ? 'start-p1-ready-badge' : 'start-p2-ready-badge';
        const barId = playerIndex === 0 ? 'start-p1-ready-bar' : 'start-p2-ready-bar';
        const badge = document.getElementById(badgeId);
        const bar = document.getElementById(barId);
        if (!badge) return;

        const pName = playerIndex === 0 ? 'P1' : 'P2';
        if (bar) {
            bar.style.width = `${Math.floor(progress * 100)}%`;
        }

        if (isReady) {
            badge.className = 'ready-badge ready';
            badge.querySelector('.rb-text').textContent = `${pName}: PRÊT ✓`;
        } else {
            badge.className = 'ready-badge waiting';
            if (progress > 0) {
                badge.querySelector('.rb-text').textContent = `${pName}: MAINTENEZ... ${Math.floor(progress * 100)}%`;
            } else {
                badge.querySelector('.rb-text').textContent = `${pName}: MAINTENEZ UN BOUTON 🎮`;
            }
        }
    }

    update(dt) {
        // ALWAYS poll gamepads and update controller status UI at top of frame!
        this.inputManager.update();
        const gp1 = !!this.inputManager.gamepads[0];
        const gp2 = !!this.inputManager.gamepads[1];
        this.updateGamepadStatusUI(gp1, gp2);

        if (this.gameState === 'START') {
            this.updateMenuCursors(dt);
            this.updateStartReadyLoop(dt);
            return;
        }

        if (this.gameState === 'VICTORY') {
            this.updateMenuCursors(dt);
            this.updateVictoryReadyLoop(dt);

            // Permet aux particules de sang/texte de continuer de s'animer
            this.particleSystem.update(dt);
            this.ambientParticles.update(dt);

            // Decay visual effects for both players
            for (const p of this.players) {
                if (p.screenShake > 0) p.screenShake = Math.max(0, p.screenShake - dt * 10);
                if (p.punchZoom > 0) p.punchZoom = Math.max(0, p.punchZoom - dt * 12);
                if (p.vignetteFlash > 0) p.vignetteFlash = Math.max(0, p.vignetteFlash - dt * 5);
                if (p.ghostHp > p.hp) p.ghostHp = Math.max(p.hp, p.ghostHp - dt * 60);
            }

            // Slow motion decay
            if (this.slowMotionTimer > 0) this.slowMotionTimer -= dt;

            // Kill feed decay
            for (let i = this.killFeedEntries.length - 1; i >= 0; i--) {
                this.killFeedEntries[i].life -= dt;
                if (this.killFeedEntries[i].life <= 0) this.killFeedEntries.splice(i, 1);
            }

            // Post-mortem recording to let the bullet tracer travel and blood splatter
            if (this.postMortemTimer !== undefined && this.postMortemTimer > 0) {
                this.postMortemTimer -= dt;
                this.replaySystem.recordFrame(dt, this);

                if (this.postMortemTimer <= 0) {
                    // Setup replay now that we have the final aftermath frames
                    this.replayStartFrame = Math.max(0, this.replaySystem.frames.length - 120);
                    this.replayCurrentFrame = this.replayStartFrame;
                    this.replayFinished = false;
                    this.freezeTimer = 1.0; // 1 second freeze before modal appears
                }
                return; // Do not process playback yet
            }

            // Replay Playback Logic (Variable speed and freeze)
            if (this.replaySystem.frames.length > 0) {
                // If player presses the skip button (DualSense ✕ / Xbox A / X key) during replay, skip straight to frozen impact frame!
                const skipPressed = this.inputManager.isSkipButtonHeld(0) || this.inputManager.isSkipButtonHeld(1);
                if (skipPressed && (!this.replayFinished || this.freezeTimer > 0)) {
                    const totalFrames = this.replaySystem.frames.length - 1;
                    this.replayCurrentFrame = totalFrames;
                    this.replayFinished = true;
                    this.killcamZoomProgress = 1.0;
                    this.freezeTimer = 0;
                    this.currentReplaySnapshot = this.replaySystem.frames[totalFrames];
                    const modal = document.getElementById('victory-modal');
                    if (modal) modal.classList.remove('hidden');
                } else if (!this.replayFinished) {
                    const totalFrames = this.replaySystem.frames.length - 1;
                    const framesLeft = totalFrames - this.replayCurrentFrame;

                    // Slow down to 0.25x speed during the last 0.5s of action (30 frames)
                    const speed = framesLeft <= 30 ? 0.25 : 1.0;

                    if (framesLeft <= 30) {
                        this.killcamZoomProgress = 1.0 - (framesLeft / 30);
                    } else {
                        this.killcamZoomProgress = 0.0;
                    }

                    this.replayCurrentFrame += (dt * 60) * speed;

                    let frameIdx = Math.floor(this.replayCurrentFrame);
                    if (frameIdx >= totalFrames) {
                        frameIdx = totalFrames;
                        this.replayFinished = true; // Freeze on impact!
                        this.killcamZoomProgress = 1.0;
                    }
                    this.currentReplaySnapshot = this.replaySystem.frames[frameIdx];
                } else {
                    // Replay finished, waiting during freeze
                    if (this.freezeTimer > 0) {
                        this.freezeTimer -= dt;
                        if (this.freezeTimer <= 0) {
                            const modal = document.getElementById('victory-modal');
                            if (modal) modal.classList.remove('hidden');
                        }
                    }
                }
            } else {
                this.replayFinished = true;
                this.freezeTimer = 0;
                const modal = document.getElementById('victory-modal');
                if (modal) modal.classList.remove('hidden');
            }

            if (this.replayFinished && this.freezeTimer <= 0) {
                this.updateMenuCursors(dt);
                this.updateVictoryReadyLoop(dt);
            }

            return;
        }

        if (this.gameState !== 'PLAYING') return;

        // Slow motion effect
        let effectiveDt = dt;
        if (this.slowMotionTimer > 0) {
            this.slowMotionTimer -= dt;
            effectiveDt = dt * 0.25;
            if (this.slowMotionTimer <= 0) this.slowMotionTimer = 0;
        }

        // Round fade-in
        if (this.roundFadeIn > 0) {
            this.roundFadeIn -= dt * 2.5;
            if (this.roundFadeIn < 0) this.roundFadeIn = 0;
        }

        // Ambient particles
        this.ambientParticles.update(effectiveDt);

        // Round Timer
        this.roundTimer -= dt;
        if (this.roundTimer <= 0) {
            this.roundTimer = 0;
            this.triggerRoundEnd(null, "TEMPS ÉCOULÉ - ÉGALITÉ");
        }

        const viewWidth = this.canvas.width / 2;
        const viewHeight = this.canvas.height;

        const vP1 = { x: 0, y: 0, width: viewWidth, height: viewHeight, camX: this.cam[0].x, camY: this.cam[0].y };
        const vP2 = { x: viewWidth, y: 0, width: viewWidth, height: viewHeight, camX: this.cam[1].x, camY: this.cam[1].y };

        const inP1 = this.inputManager.getPlayerInput(0, this.players[0], vP1);
        const inP2 = this.inputManager.getPlayerInput(1, this.players[1], vP2);

        this.players[0].update(effectiveDt, inP1, this.map.segments, this.audioEngine);
        this.players[1].update(effectiveDt, inP2, this.map.segments, this.audioEngine);

        // Dazzle detection: check if each player is being blinded by opponent's flashlight
        this.updateDazzle(this.players[0], this.players[1], effectiveDt);
        this.updateDazzle(this.players[1], this.players[0], effectiveDt);

        // Camera lerp
        this.cam[0].x += (this.players[0].x - this.cam[0].x) * Math.min(1, effectiveDt * this.camLerpSpeed);
        this.cam[0].y += (this.players[0].y - this.cam[0].y) * Math.min(1, effectiveDt * this.camLerpSpeed);
        this.cam[1].x += (this.players[1].x - this.cam[1].x) * Math.min(1, effectiveDt * this.camLerpSpeed);
        this.cam[1].y += (this.players[1].y - this.cam[1].y) * Math.min(1, effectiveDt * this.camLerpSpeed);

        // SHOOTING logic happens manually here based on input (disabled if actively sprinting)
        if (inP1.shoot && !this.players[0].isSprinting) this.shootGun(this.players[0]);
        if (inP2.shoot && !this.players[1].isSprinting) this.shootGun(this.players[1]);

        for (let i = this.bullets.length - 1; i >= 0; i--) {
            const b = this.bullets[i];
            b.update(effectiveDt, this.map.segments, this.players, this.particleSystem, this.audioEngine);
            if (!b.alive) {
                this.bullets.splice(i, 1);
            }
        }

        this.particleSystem.update(effectiveDt);

        // Score animation detection
        if (this.players[0].score !== this.prevScoreP1) {
            this.scoreAnimP1 = 1.0;
            this.prevScoreP1 = this.players[0].score;
        }
        if (this.players[1].score !== this.prevScoreP2) {
            this.scoreAnimP2 = 1.0;
            this.prevScoreP2 = this.players[1].score;
        }
        if (this.scoreAnimP1 > 0) this.scoreAnimP1 -= effectiveDt * 3;
        if (this.scoreAnimP2 > 0) this.scoreAnimP2 -= effectiveDt * 3;

        // Heartbeat when low HP
        this.heartbeatTimer -= effectiveDt;
        if (this.heartbeatTimer <= 0) {
            if (this.players[0].hp > 0 && this.players[0].hp <= 30) {
                this.audioEngine.playHeartbeat();
            }
            if (this.players[1].hp > 0 && this.players[1].hp <= 30) {
                this.audioEngine.playHeartbeat();
            }
            this.heartbeatTimer = 0.8;
        }

        // Kill feed decay
        for (let i = this.killFeedEntries.length - 1; i >= 0; i--) {
            this.killFeedEntries[i].life -= effectiveDt;
            if (this.killFeedEntries[i].life <= 0) {
                this.killFeedEntries.splice(i, 1);
            }
        }

        // Record frame for killcam replay (record before death check to capture the fatal frame)
        if (this.gameState === 'PLAYING') {
            this.replaySystem.recordFrame(effectiveDt, this);
        }

        if (this.players[0].hp <= 0) {
            this.players[1].score++;
            this.audioEngine.playKill();
            this.triggerRoundEnd(this.players[1], "ATTACK FROM SHADOWS");
        } else if (this.players[1].hp <= 0) {
            this.players[0].score++;
            this.audioEngine.playKill();
            this.triggerRoundEnd(this.players[0], "ATTACK FROM SHADOWS");
        }

        this.updateGamepadStatusUI(inP1.hasGamepad, inP2.hasGamepad);
    }

    updateVictoryReadyLoop(dt) {
        // Player 1 Hold Detection
        if (this.inputManager.isAnyButtonHeld(0)) {
            this.p1HoldTimer += dt;
        } else if (!this.p1Ready) {
            this.p1HoldTimer = Math.max(0, this.p1HoldTimer - dt * 2.5);
        }

        const p1Prog = Math.min(1.0, this.p1HoldTimer / this.requiredHoldTime);
        if (p1Prog >= 1.0 && !this.p1Ready) {
            this.p1Ready = true;
            this.audioEngine.playTorchClick(true);
        }
        this.updateReadyUI(0, this.p1Ready, p1Prog);

        // Player 2 Hold Detection
        if (this.inputManager.isAnyButtonHeld(1)) {
            this.p2HoldTimer += dt;
        } else if (!this.p2Ready) {
            this.p2HoldTimer = Math.max(0, this.p2HoldTimer - dt * 2.5);
        }

        const p2Prog = Math.min(1.0, this.p2HoldTimer / this.requiredHoldTime);
        if (p2Prog >= 1.0 && !this.p2Ready) {
            this.p2Ready = true;
            this.audioEngine.playTorchClick(true);
        }
        this.updateReadyUI(1, this.p2Ready, p2Prog);

        if (this.p1Ready && this.p2Ready) {
            this.startNextRound();
        }
    }

    updateReadyUI(playerIndex, isReady, progress = 0) {
        const badgeId = playerIndex === 0 ? 'p1-ready-badge' : 'p2-ready-badge';
        const barId = playerIndex === 0 ? 'p1-ready-bar' : 'p2-ready-bar';
        const badge = document.getElementById(badgeId);
        const bar = document.getElementById(barId);
        if (!badge) return;

        const pName = playerIndex === 0 ? 'P1' : 'P2';
        if (bar) {
            bar.style.width = `${Math.floor(progress * 100)}%`;
        }

        if (isReady) {
            badge.className = 'ready-badge ready';
            badge.querySelector('.rb-text').textContent = `${pName}: PRÊT ✓`;
        } else {
            badge.className = 'ready-badge waiting';
            if (progress > 0) {
                badge.querySelector('.rb-text').textContent = `${pName}: MAINTENEZ... ${Math.floor(progress * 100)}%`;
            } else {
                badge.querySelector('.rb-text').textContent = `${pName}: MAINTENEZ UN BOUTON 🎮`;
            }
        }
    }

    triggerRoundEnd(winner, desc) {
        this.slowMotionTimer = 0.5;
        this.audioEngine.stopAmbientDrone();
        this.gameState = 'VICTORY';

        // Delay replay setup to let the bullet tracer and blood particles travel
        this.postMortemTimer = 0.20; // 200ms
        this.killcamZoomProgress = 0.0;

        this.p1Ready = false;
        this.p2Ready = false;
        this.p1HoldTimer = 0;
        this.p2HoldTimer = 0;

        this.updateReadyUI(0, false, 0);
        this.updateReadyUI(1, false, 0);

        const modal = document.getElementById('victory-modal');
        const title = document.getElementById('victory-title');
        const descEl = document.getElementById('victory-desc');

        if (winner) {
            title.textContent = `${winner.name} REMPORTE LA MANCHE !`;
            title.style.color = winner.color;
        } else {
            title.textContent = "ÉGALITÉ !";
            title.style.color = "#ffb700";
        }

        descEl.textContent = desc;
        document.getElementById('modal-p1-score').textContent = this.players[0].score;
        document.getElementById('modal-p2-score').textContent = this.players[1].score;
    }

    updateGamepadStatusUI(gp1, gp2) {
        const el1 = document.getElementById('gp1-status');
        const el2 = document.getElementById('gp2-status');
        const startEl1 = document.getElementById('start-gp1-status');
        const startEl2 = document.getElementById('start-gp2-status');

        const raw1 = this.inputManager.gamepads[0];
        const raw2 = this.inputManager.gamepads[1];

        if (gp1 && raw1) {
            const name = raw1.id ? raw1.id.split('(')[0].trim().substring(0, 18) : 'CONNECTÉE';
            if (el1) {
                el1.className = 'gp-badge connected';
                el1.querySelector('.gp-name').textContent = `M1: ${name} ✓`;
            }
            if (startEl1) {
                startEl1.className = 'gp-badge connected start-gp-status';
                startEl1.querySelector('.gp-name').textContent = `MANETTE 1: CONNECTÉE ✓`;
            }
        } else {
            if (el1) {
                el1.className = 'gp-badge disconnected';
                el1.querySelector('.gp-name').textContent = 'M1: APPUYEZ SUR UN BOUTON...';
            }
            if (startEl1) {
                startEl1.className = 'gp-badge disconnected start-gp-status';
                startEl1.querySelector('.gp-name').textContent = 'MANETTE 1: NON CONNECTÉE';
            }
        }

        if (gp2 && raw2) {
            const name = raw2.id ? raw2.id.split('(')[0].trim().substring(0, 18) : 'CONNECTÉE';
            if (el2) {
                el2.className = 'gp-badge connected';
                el2.querySelector('.gp-name').textContent = `M2: ${name} ✓`;
            }
            if (startEl2) {
                startEl2.className = 'gp-badge connected start-gp-status';
                startEl2.querySelector('.gp-name').textContent = `MANETTE 2: CONNECTÉE ✓`;
            }
        } else {
            if (el2) {
                el2.className = 'gp-badge disconnected';
                el2.querySelector('.gp-name').textContent = 'M2: APPUYEZ SUR UN BOUTON...';
            }
            if (startEl2) {
                startEl2.className = 'gp-badge disconnected start-gp-status';
                startEl2.querySelector('.gp-name').textContent = 'MANETTE 2: NON CONNECTÉE';
            }
        }

        // Dynamically hide/show the "optimal experience" notice when 2 gamepads are connected
        const noticeEl = document.getElementById('gamepad-notice');
        if (noticeEl) {
            const bothConnected = (gp1 && gp2 && raw1 && raw2);
            noticeEl.style.display = bothConnected ? 'none' : 'flex';
        }
    }

    render() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        if (this.gameState === 'VICTORY') {
            this.renderKillcam();
            this.renderKillFeed();
            return;
        }

        const w = this.canvas.width / 2;
        const h = this.canvas.height;

        // Render P1 Viewport (Left half)
        this.renderViewport(0, 0, w, h, this.players[0], this.players[1]);

        // Render P2 Viewport (Right half)
        this.renderViewport(w, 0, w, h, this.players[1], this.players[0]);

        // Draw Split Screen Vertical Center Divider
        this.ctx.save();
        this.ctx.strokeStyle = '#00f0ff';
        this.ctx.lineWidth = 2;
        this.ctx.shadowColor = '#00f0ff';
        this.ctx.shadowBlur = 10;
        this.ctx.beginPath();
        this.ctx.moveTo(w, 0);
        this.ctx.lineTo(w, h);
        this.ctx.stroke();
        this.ctx.restore();

        // Update HUD Gauges
        this.renderHUD();
    }

    renderKillcam() {
        const vw = this.canvas.width;
        const vh = this.canvas.height;
        this.ctx.save();

        // Fit map into screen (global view)
        const globalScale = Math.min(vw / this.map.width, vh / this.map.height) * 0.95;
        const globalTargetX = this.map.width / 2;
        const globalTargetY = this.map.height / 2;

        let finalScale = globalScale;
        let targetX = globalTargetX;
        let targetY = globalTargetY;

        const snap = this.currentReplaySnapshot;
        if (snap && this.killcamZoomProgress !== undefined && this.killcamZoomProgress > 0) {
            const p1 = snap.players[0];
            const p2 = snap.players[1];

            // Calculate bounding box of players
            const dx = Math.abs(p1.x - p2.x);
            const dy = Math.abs(p1.y - p2.y);
            const padding = 350; // px
            let zoomScale = Math.min(vw / (dx + padding), vh / (dy + padding));
            zoomScale = Math.min(zoomScale, globalScale * 3.5); // Max zoom is 3.5x global
            zoomScale = Math.max(zoomScale, globalScale); // Ensure we don't zoom out

            // Cubic ease out
            const t = this.killcamZoomProgress;
            const ease = 1 - Math.pow(1 - t, 3);

            finalScale = globalScale + (zoomScale - globalScale) * ease;

            const zoomTargetX = (p1.x + p2.x) / 2;
            const zoomTargetY = (p1.y + p2.y) / 2;

            targetX = globalTargetX + (zoomTargetX - globalTargetX) * ease;
            targetY = globalTargetY + (zoomTargetY - globalTargetY) * ease;
        }

        const offsetX = (vw / 2) - (targetX * finalScale);
        const offsetY = (vh / 2) - (targetY * finalScale);

        this.ctx.translate(offsetX, offsetY);
        this.ctx.scale(finalScale, finalScale);

        // 1. Draw Floor Grid over entire map
        this.drawFloorGrid(0, 0, this.map.width, this.map.height);

        // Use replay snapshot if available, otherwise fallback to live state
        // snap is already declared above
        const bulletsToDraw = snap ? snap.bullets : this.bullets;
        const p1ToDraw = snap ? snap.players[0] : this.players[0];
        const p2ToDraw = snap ? snap.players[1] : this.players[1];

        // 1b. Draw bullet decals (we use live decals since they persist and look cool)
        this.ctx.save();
        for (let i = 0; i < this.bulletDecals.length; i++) {
            const d = this.bulletDecals[i];
            this.ctx.globalAlpha = d.alpha * 0.5;
            this.ctx.fillStyle = '#1a1a2e';
            this.ctx.beginPath();
            this.ctx.arc(d.x, d.y, d.size, 0, Math.PI * 2);
            this.ctx.fill();
        }
        this.ctx.restore();

        // 1c. Draw ambient particles
        this.ambientParticles.draw(this.ctx);

        // 2. Draw Map Obstacles
        this.drawMapObstacles();

        // 3. Draw Bullets & Particles
        for (let i = 0; i < bulletsToDraw.length; i++) {
            this.drawBullet(bulletsToDraw[i]);
        }

        if (snap) {
            const liveParticles = this.particleSystem.particles;
            this.particleSystem.particles = snap.particles;
            this.particleSystem.draw(this.ctx);
            this.particleSystem.particles = liveParticles;
        } else {
            this.particleSystem.draw(this.ctx);
        }

        // 3.5 Draw Flashlight Beams in Killcam
        if (p1ToDraw.flashlightOn) {
            const segsP1 = [...this.map.segments, ...this.getPlayerSegments(p2ToDraw)];
            const p1LightPoly = RaycastEngine.calculateVisibilityPolygon(
                p1ToDraw.x, p1ToDraw.y, p1ToDraw.flashlightRange, segsP1, p1ToDraw.angle, p1ToDraw.flashlightFov
            );
            this.drawFlashlightGlow(p1ToDraw, p1LightPoly);
        }
        if (p2ToDraw.flashlightOn) {
            const segsP2 = [...this.map.segments, ...this.getPlayerSegments(p1ToDraw)];
            const p2LightPoly = RaycastEngine.calculateVisibilityPolygon(
                p2ToDraw.x, p2ToDraw.y, p2ToDraw.flashlightRange, segsP2, p2ToDraw.angle, p2ToDraw.flashlightFov
            );
            this.drawFlashlightGlow(p2ToDraw, p2LightPoly);
        }

        // 4. Draw Both Players (force revealed)
        this.drawPlayerAvatar(p1ToDraw, false, true);
        this.drawPlayerAvatar(p2ToDraw, false, true);

        // 5. Brighten the map slightly to look like daytime/revealed
        this.ctx.fillStyle = 'rgba(255, 255, 255, 0.05)';
        this.ctx.fillRect(0, 0, this.map.width, this.map.height);

        // 6. Draw "REPLAY" text in top left and "Appuyer sur ✕ pour passer" in top right
        this.ctx.restore();
        this.ctx.save();
        this.ctx.fillStyle = 'rgba(255, 0, 0, 0.8)';
        this.ctx.font = '800 24px Orbitron';
        this.ctx.fillText("🔴 REPLAY", 30, 40);

        // Detect connected gamepad to display appropriate prompt icon (✕ / A / X)
        const hasGamepad = !!(this.inputManager.gamepads[0] || this.inputManager.gamepads[1]);
        const promptText = hasGamepad ? "Appuyer sur ✕ pour passer" : "Appuyer sur X (ou ✕) pour passer";

        this.ctx.fillStyle = 'rgba(255, 255, 255, 0.75)';
        this.ctx.font = '600 16px Orbitron';
        this.ctx.textAlign = 'right';
        this.ctx.fillText(`[ ${promptText} ]`, vw - 30, 40);
        this.ctx.restore();
    }

    getPlayerSegments(player) {
        if (!player || player.hp <= 0) return [];
        const segs = [];
        const r = player.radius;
        const sides = 8;
        for (let i = 0; i < sides; i++) {
            const a1 = (i / sides) * Math.PI * 2;
            const a2 = ((i + 1) / sides) * Math.PI * 2;
            segs.push(new LineSegment(
                player.x + Math.cos(a1) * r,
                player.y + Math.sin(a1) * r,
                player.x + Math.cos(a2) * r,
                player.y + Math.sin(a2) * r
            ));
        }
        return segs;
    }

    getClampedDazzleOffset(player, dazzleAmount) {
        const d = Math.min(1.0, dazzleAmount);
        const desiredOffset = d * 100;
        let maxDist = desiredOffset;

        const backAngle = player.angle + Math.PI;
        const backRay = {
            a: { x: player.x, y: player.y },
            b: { x: player.x + Math.cos(backAngle) * desiredOffset, y: player.y + Math.sin(backAngle) * desiredOffset }
        };

        if (this.map && this.map.segments) {
            for (let i = 0; i < this.map.segments.length; i++) {
                const intersect = RaycastEngine.getIntersection(backRay, this.map.segments[i]);
                if (intersect && intersect.param >= 0 && intersect.param <= 1) {
                    const dist = intersect.param * desiredOffset;
                    if (dist < maxDist) {
                        maxDist = dist;
                    }
                }
            }
        }

        return Math.max(0, maxDist - 10);
    }

    renderViewport(vx, vy, vw, vh, viewer, opponent) {
        this.ctx.save();

        // Clip Viewport Bounds
        this.ctx.beginPath();
        this.ctx.rect(vx, vy, vw, vh);
        this.ctx.clip();

        // Camera Shake Translation
        let shakeX = 0, shakeY = 0;
        if (viewer.screenShake > 0) {
            shakeX = (Math.random() - 0.5) * viewer.screenShake * 12;
            shakeY = (Math.random() - 0.5) * viewer.screenShake * 12;
        }

        // Camera Offset (smooth lerped)
        const camIdx = viewer.id;
        const smoothCamX = this.cam[camIdx] ? this.cam[camIdx].x : viewer.x;
        const smoothCamY = this.cam[camIdx] ? this.cam[camIdx].y : viewer.y;
        const punchScale = 1.0 + viewer.punchZoom * 0.03;
        const camX = smoothCamX - vw / 2 + shakeX;
        const camY = smoothCamY - vh / 2 + shakeY;

        this.ctx.translate(vx + vw / 2, vy + vh / 2);
        this.ctx.scale(punchScale, punchScale);
        this.ctx.translate(-vw / 2 - camX, -vh / 2 - camY);

        // 1. Draw Floor Grid
        this.drawFloorGrid(camX, camY, vw, vh);

        // 1b. Draw bullet decals
        this.ctx.save();
        for (let i = 0; i < this.bulletDecals.length; i++) {
            const d = this.bulletDecals[i];
            this.ctx.globalAlpha = d.alpha * 0.5;
            this.ctx.fillStyle = '#1a1a2e';
            this.ctx.beginPath();
            this.ctx.arc(d.x, d.y, d.size, 0, Math.PI * 2);
            this.ctx.fill();
        }
        this.ctx.restore();

        // 1c. Draw ambient particles
        this.ambientParticles.draw(this.ctx);

        // 2. Compute Visibility Light Polygons (Including opponent obstacle segments for dynamic player shadows!)
        let viewerLightPoly = null;
        let opponentLightPoly = null;

        const segsForViewer = [...this.map.segments, ...this.getPlayerSegments(opponent)];
        const segsForOpponent = [...this.map.segments, ...this.getPlayerSegments(viewer)];

        if (viewer.flashlightOn) {
            viewerLightPoly = RaycastEngine.calculateVisibilityPolygon(
                viewer.x, viewer.y, viewer.flashlightRange, segsForViewer, viewer.angle, viewer.flashlightFov
            );
        }

        let oppWideLightPoly = null;
        if (opponent.flashlightOn) {
            opponentLightPoly = RaycastEngine.calculateVisibilityPolygon(
                opponent.x, opponent.y, opponent.flashlightRange, segsForOpponent, opponent.angle, opponent.flashlightFov
            );
            if (viewer.dazzleAmount > 0.1) {
                const offset = this.getClampedDazzleOffset(opponent, viewer.dazzleAmount);
                const originX = opponent.x - Math.cos(opponent.angle) * offset;
                const originY = opponent.y - Math.sin(opponent.angle) * offset;
                const widenedFov = Math.PI * 0.45;
                oppWideLightPoly = RaycastEngine.calculateVisibilityPolygon(
                    originX, originY, opponent.flashlightRange * 1.5 + offset, this.map.segments, opponent.angle, widenedFov
                );
            }
        }

        // 3. DARKNESS FOG LAYER - Reuse pre-allocated canvas for performance
        if (!this.fogCanvas || this.fogCanvas.width !== vw || this.fogCanvas.height !== vh) {
            this.fogCanvas = document.createElement('canvas');
            this.fogCanvas.width = vw;
            this.fogCanvas.height = vh;
            this.fogCtx = this.fogCanvas.getContext('2d');
        }
        const offCanvas = this.fogCanvas;
        const offCtx = this.fogCtx;
        offCtx.clearRect(0, 0, vw, vh);

        // Fill pitch black
        offCtx.fillStyle = 'rgba(4, 7, 14, 1.0)';
        offCtx.fillRect(0, 0, vw, vh);

        offCtx.save();
        offCtx.translate(-camX, -camY);
        offCtx.globalCompositeOperation = 'destination-out';

        // Cut Viewer Flashlight Beam
        if (viewerLightPoly && viewerLightPoly.length > 0) {
            offCtx.beginPath();
            offCtx.moveTo(viewerLightPoly[0].x, viewerLightPoly[0].y);
            for (let i = 1; i < viewerLightPoly.length; i++) {
                offCtx.lineTo(viewerLightPoly[i].x, viewerLightPoly[i].y);
            }
            offCtx.closePath();
            offCtx.fill();
        }

        // Cut Opponent Flashlight Beam (if ON - use wide poly when dazzled so narrow cone cutout disappears)
        const opponentPolyToCut = (viewer.dazzleAmount > 0.1 && oppWideLightPoly) ? oppWideLightPoly : opponentLightPoly;
        if (opponentPolyToCut && opponentPolyToCut.length > 0) {
            offCtx.beginPath();
            offCtx.moveTo(opponentPolyToCut[0].x, opponentPolyToCut[0].y);
            for (let i = 1; i < opponentPolyToCut.length; i++) {
                offCtx.lineTo(opponentPolyToCut[i].x, opponentPolyToCut[i].y);
            }
            offCtx.closePath();
            offCtx.fill();
        }

        // Cut Ambient Self Halo around Viewer (So player can see immediate feet)
        offCtx.beginPath();
        offCtx.arc(viewer.x, viewer.y, 50, 0, Math.PI * 2);
        offCtx.fill();

        // Cut Muzzle Flash Light Spheres (0.5s rapid fade)
        if (viewer.lastMuzzleFlash > 2.0) {
            const ratio = (viewer.lastMuzzleFlash - 2.0) / 0.5;
            const flashRadius = 40 + ratio * 180;
            offCtx.save();
            offCtx.globalAlpha = Math.max(0, ratio);
            offCtx.beginPath();
            offCtx.arc(viewer.x, viewer.y, flashRadius, 0, Math.PI * 2);
            offCtx.fill();
            offCtx.restore();
        }

        if (opponent.lastMuzzleFlash > 2.0) {
            const ratio = (opponent.lastMuzzleFlash - 2.0) / 0.5;
            const flashRadius = 40 + ratio * 180;
            offCtx.save();
            offCtx.globalAlpha = Math.max(0, ratio);
            offCtx.beginPath();
            offCtx.arc(opponent.x, opponent.y, flashRadius, 0, Math.PI * 2);
            offCtx.fill();
            offCtx.restore();
        }

        // Cut Bullet Spark Lights
        for (let i = 0; i < this.bullets.length; i++) {
            const b = this.bullets[i];
            offCtx.beginPath();
            offCtx.arc(b.x, b.y, 35, 0, Math.PI * 2);
            offCtx.fill();
        }

        offCtx.restore();

        // 4. Draw Map Obstacles
        this.drawMapObstacles();

        // 4.5. Draw Viewer's Dotted Sightline (Drawn before darkness fog overlay, so it is only visible in lit areas & fades with light)
        if (viewer.hp > 0) {
            this.drawPlayerSightline(viewer);
        }

        // 5. Overlay the Darkness Fog Buffer on Viewport (Under Avatars & Particles)
        this.ctx.drawImage(offCanvas, camX, camY);

        // 6. Draw Light Beams Aesthetics (Glow Gradients)
        this.drawFlashlightGlow(viewer, viewerLightPoly, 0, null, camX, camY, vw, vh);

        if (opponent.flashlightOn) {
            this.drawFlashlightGlow(opponent, opponentLightPoly, viewer.dazzleAmount, oppWideLightPoly, camX, camY, vw, vh);
        }

        // 7. Draw Bullets & Particles
        for (let i = 0; i < this.bullets.length; i++) {
            this.drawBullet(this.bullets[i]);
        }
        this.particleSystem.draw(this.ctx);

        // 8. GOLD RULE CHECK: IS OPPONENT VISIBLE TO VIEWER?
        const isOpponentLit = this.checkIsOpponentLit(viewer, opponent, viewerLightPoly, opponentLightPoly);

        if (isOpponentLit && opponent.hp > 0) {
            this.drawPlayerAvatar(opponent, true, false, viewer.dazzleAmount);
        }

        // Always draw Viewer Avatar
        if (viewer.hp > 0) {
            this.drawPlayerAvatar(viewer, false);
        }

        // Vignette flash overlay when hit
        if (viewer.vignetteFlash > 0) {
            this.ctx.save();
            const vigGrad = this.ctx.createRadialGradient(
                smoothCamX, smoothCamY, vw * 0.2,
                smoothCamX, smoothCamY, vw * 0.7
            );
            vigGrad.addColorStop(0, 'rgba(255, 0, 50, 0)');
            vigGrad.addColorStop(1, `rgba(255, 0, 50, ${viewer.vignetteFlash * 0.5})`);
            this.ctx.fillStyle = vigGrad;
            this.ctx.fillRect(camX, camY, vw, vh);
            this.ctx.restore();
        }

        // Round fade-in overlay
        if (this.roundFadeIn > 0) {
            this.ctx.save();
            this.ctx.fillStyle = `rgba(0, 0, 0, ${this.roundFadeIn})`;
            this.ctx.fillRect(camX, camY, vw, vh);
            this.ctx.restore();
        }

        this.ctx.restore();
    }

    checkIsOpponentLit(viewer, opponent, viewerLightPoly, opponentLightPoly) {
        if (!opponent || opponent.hp <= 0) return 0.0;

        let revealFactor = 0.0;

        // 1. Is opponent inside Viewer's Flashlight Cone (with Line-of-Sight)?
        if (viewer.flashlightOn) {
            const dist = Math.hypot(opponent.x - viewer.x, opponent.y - viewer.y);
            if (dist <= viewer.flashlightRange) {
                const angleToOpp = Math.atan2(opponent.y - viewer.y, opponent.x - viewer.x);
                let diff = angleToOpp - viewer.angle;
                while (diff < -Math.PI) diff += Math.PI * 2;
                while (diff > Math.PI) diff -= Math.PI * 2;

                if (Math.abs(diff) <= viewer.flashlightFov / 2 + 0.15) {
                    // Check if map walls block line of sight between viewer and opponent
                    const losRay = { a: { x: viewer.x, y: viewer.y }, b: { x: opponent.x, y: opponent.y } };
                    let wallBlocked = false;
                    for (let i = 0; i < this.map.segments.length; i++) {
                        const intersect = RaycastEngine.getIntersection(losRay, this.map.segments[i]);
                        if (intersect && intersect.param > 0.02 && intersect.param < 0.98) {
                            wallBlocked = true;
                            break;
                        }
                    }
                    if (!wallBlocked) revealFactor = 1.0;
                }
            }
        }

        // 2. Is opponent's OWN Flashlight turned ON? (Self-betrayal!)
        if (opponent.flashlightOn) {
            revealFactor = 1.0;
        }

        // 3. Is opponent within close proximity of viewer's feet halo?
        if (Math.hypot(viewer.x - opponent.x, viewer.y - opponent.y) < 65) {
            revealFactor = 1.0;
        }

        // 4. Did opponent just fire a shot (Muzzle Flash)?
        if (opponent.lastMuzzleFlash > 0) {
            // Smooth quadratic decay curve over 2.5 seconds.
            // Starts at 1.0 (100% visible) and fades out smoothly to 0 at 2.5s.
            const t = Math.min(1.0, (2.5 - opponent.lastMuzzleFlash) / 2.5); // 0 at shot, 1 at 2.5s
            const flashFade = Math.pow(1.0 - t, 2);
            revealFactor = Math.max(revealFactor, flashFade);
        }

        return revealFactor;
    }

    drawFloorGrid(camX, camY, vw, vh) {
        const tileSize = 60;
        const startX = Math.floor(camX / tileSize) * tileSize;
        const startY = Math.floor(camY / tileSize) * tileSize;

        // Alternating floor tiles for depth
        this.ctx.save();
        for (let x = startX; x < camX + vw + tileSize; x += tileSize) {
            for (let y = startY; y < camY + vh + tileSize; y += tileSize) {
                const tx = Math.floor(x / tileSize);
                const ty = Math.floor(y / tileSize);
                if ((tx + ty) % 2 === 0) {
                    this.ctx.fillStyle = 'rgba(255, 255, 255, 0.012)';
                    this.ctx.fillRect(x, y, tileSize, tileSize);
                }
            }
        }
        this.ctx.restore();

        // Grid lines
        this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.035)';
        this.ctx.lineWidth = 1;
        this.ctx.beginPath();
        for (let x = startX; x < camX + vw + tileSize; x += tileSize) {
            this.ctx.moveTo(x, camY);
            this.ctx.lineTo(x, camY + vh);
        }
        for (let y = startY; y < camY + vh + tileSize; y += tileSize) {
            this.ctx.moveTo(camX, y);
            this.ctx.lineTo(camX + vw, y);
        }
        this.ctx.stroke();

        // Soft tactical ambient glows
        this.ctx.save();
        const centerGlow = this.ctx.createRadialGradient(700, 700, 20, 700, 700, 500);
        centerGlow.addColorStop(0, 'rgba(0, 240, 255, 0.05)');
        centerGlow.addColorStop(1, 'rgba(0, 0, 0, 0)');
        this.ctx.fillStyle = centerGlow;
        this.ctx.fillRect(200, 200, 1000, 1000);

        // Corner ambient glows
        const corners = [[100, 100], [1300, 100], [100, 1300], [1300, 1300]];
        for (const [cx, cy] of corners) {
            const glow = this.ctx.createRadialGradient(cx, cy, 10, cx, cy, 200);
            glow.addColorStop(0, 'rgba(255, 183, 0, 0.025)');
            glow.addColorStop(1, 'rgba(0, 0, 0, 0)');
            this.ctx.fillStyle = glow;
            this.ctx.fillRect(cx - 200, cy - 200, 400, 400);
        }
        this.ctx.restore();
    }

    drawFlashlightGlow(player, lightPoly, dazzleAmount = 0, wideLightPoly = null, camX = 0, camY = 0, vw = 0, vh = 0) {
        if (!player.flashlightOn || !lightPoly || lightPoly.length === 0) return;

        this.ctx.save();
        // Subtle flicker — stronger when dazzled
        const flickerBase = dazzleAmount > 0.1 ? (0.75 + Math.random() * 0.25) : 1.0;
        const flickerAlpha = (0.88 + Math.random() * 0.12) * flickerBase;
        this.ctx.globalAlpha = flickerAlpha;

        // When viewer is dazzled, the beam appears brighter and more intense at the origin
        const d = Math.min(1.0, dazzleAmount);
        const originBright = 0.8 + d * 0.2;   // origin glow: 0.8 → 1.0
        const midBright = 0.4 + d * 0.45;      // mid glow:    0.4 → 0.85
        const tipBright = 0.0 + d * 0.3;       // tip glow:    0.0 → 0.3

        const grad = this.ctx.createRadialGradient(
            player.x, player.y, 10,
            player.x, player.y, player.flashlightRange
        );
        grad.addColorStop(0, `rgba(255, 245, 220, ${originBright})`);
        grad.addColorStop(0.3, `rgba(255, 230, 170, ${midBright})`);
        grad.addColorStop(1, `rgba(255, 210, 120, ${tipBright})`);

        // The original sharp cone fades out rapidly when dazzled so only the soft dazzle cone is visible
        this.ctx.globalAlpha = Math.max(0, 1.0 - d * 3) * flickerAlpha;
        this.ctx.fillStyle = grad;
        this.ctx.beginPath();
        this.ctx.moveTo(lightPoly[0].x, lightPoly[0].y);
        for (let i = 1; i < lightPoly.length; i++) {
            this.ctx.lineTo(lightPoly[i].x, lightPoly[i].y);
        }
        this.ctx.closePath();
        this.ctx.fill();
        this.ctx.globalAlpha = 1.0;

        // When dazzled, flood the beam with white and widen the visible cone
        if (d > 0.1 && wideLightPoly) {
            const w = vw || this.canvas.width;
            const h = vh || this.canvas.height;
            if (!this.dazzleCanvas || this.dazzleCanvas.width !== w || this.dazzleCanvas.height !== h) {
                this.dazzleCanvas = document.createElement('canvas');
                this.dazzleCanvas.width = w;
                this.dazzleCanvas.height = h;
                this.dazzleCtx = this.dazzleCanvas.getContext('2d');
            }

            const dCtx = this.dazzleCtx;
            dCtx.clearRect(0, 0, w, h);
            dCtx.save();
            dCtx.translate(-camX, -camY);

            // Clip to wideLightPoly in offscreen context so it respects walls
            dCtx.beginPath();
            dCtx.moveTo(wideLightPoly[0].x, wideLightPoly[0].y);
            for (let i = 1; i < wideLightPoly.length; i++) {
                dCtx.lineTo(wideLightPoly[i].x, wideLightPoly[i].y);
            }
            dCtx.closePath();
            dCtx.clip();

            // Offset the origin of the dazzle backward (clamped if near a wall behind the player)
            const offset = this.getClampedDazzleOffset(player, dazzleAmount);
            const originX = player.x - Math.cos(player.angle) * offset;
            const originY = player.y - Math.sin(player.angle) * offset;

            // Transform to draw symmetrical ellipses along the beam's central axis
            dCtx.translate(originX, originY);
            dCtx.rotate(player.angle);

            // Increase the drawing range by the offset so the beam still reaches the viewer
            const ellipseRange = player.flashlightRange + offset;

            // Calculate the maximum expanded angle (halved expansion)
            const widenedFov = player.flashlightFov + (Math.PI * 0.3 * d);
            const maxAngle = widenedFov / 2;

            // Draw stacked ellipses to create a flawless Angular AND Radial fade.
            const layers = 8;
            for (let l = 1; l <= layers; l++) {
                const t = l / layers;
                const angle = maxAngle * t;
                const scaleY = Math.tan(angle);

                dCtx.save();
                dCtx.scale(1.0, scaleY);

                const layerAlpha = (1.0 - t + 0.05);
                const baseAlpha = 0.5 * layerAlpha * d * flickerBase;

                const ellipseGrad = dCtx.createRadialGradient(
                    0, 0, ellipseRange * 0.1,
                    0, 0, ellipseRange
                );
                ellipseGrad.addColorStop(0, `rgba(255, 255, 255, ${baseAlpha})`);
                ellipseGrad.addColorStop(0.4, `rgba(255, 255, 250, ${baseAlpha * 0.8})`);
                ellipseGrad.addColorStop(0.8, `rgba(255, 252, 240, ${baseAlpha * 0.3})`);
                ellipseGrad.addColorStop(1, 'rgba(255, 245, 220, 0)');

                dCtx.fillStyle = ellipseGrad;
                dCtx.beginPath();
                dCtx.arc(0, 0, ellipseRange, 0, Math.PI * 2);
                dCtx.fill();

                dCtx.restore();
            }

            dCtx.restore();

            // Draw offscreen buffer onto main canvas WITH A REAL BLUR FILTER (blurs sharp clip & peak vertex!)
            this.ctx.save();
            this.ctx.filter = `blur(${Math.round(d * 50)}px)`;
            this.ctx.drawImage(this.dazzleCanvas, camX, camY);
            this.ctx.restore();
        }


        this.ctx.restore();
    }

    drawMapObstacles() {
        this.ctx.save();
        this.ctx.fillStyle = '#0f172a';
        this.ctx.strokeStyle = '#334155';
        this.ctx.lineWidth = 2;

        for (let i = 0; i < this.map.obstacles.length; i++) {
            const obs = this.map.obstacles[i];
            this.ctx.fillRect(obs.x, obs.y, obs.w, obs.h);
            this.ctx.strokeRect(obs.x, obs.y, obs.w, obs.h);
        }

        // Draw Line Segments / Walls
        this.ctx.strokeStyle = '#475569';
        this.ctx.lineWidth = 4;
        this.ctx.beginPath();
        for (let i = 0; i < this.map.segments.length; i++) {
            const s = this.map.segments[i];
            this.ctx.moveTo(s.p1.x, s.p1.y);
            this.ctx.lineTo(s.p2.x, s.p2.y);
        }
        this.ctx.stroke();

        this.ctx.restore();
    }

    drawBullet(bullet) {
        this.ctx.save();
        this.ctx.fillStyle = '#ffe600';
        this.ctx.shadowColor = '#ffe600';
        this.ctx.shadowBlur = 12;

        this.ctx.beginPath();
        this.ctx.arc(bullet.x, bullet.y, bullet.radius, 0, Math.PI * 2);
        this.ctx.fill();

        this.ctx.restore();
    }

    drawPlayerSightline(player) {
        if (!player || player.hp <= 0) return;

        const barrelLen = player.radius + 14;
        const startX = player.x + Math.cos(player.angle) * barrelLen;
        const startY = player.y + Math.sin(player.angle) * barrelLen;

        const maxDist = 5000;
        const endX = startX + Math.cos(player.angle) * maxDist;
        const endY = startY + Math.sin(player.angle) * maxDist;

        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.setLineDash([6, 6]);
        this.ctx.moveTo(startX, startY);
        this.ctx.lineTo(endX, endY);
        this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.35)';
        this.ctx.lineWidth = 1.0;
        this.ctx.stroke();
        this.ctx.restore();
    }

    drawPlayerAvatar(player, isOpponent = false, forceReveal = false, dazzleAmount = 0) {
        this.ctx.save();

        let revealAlpha = 0.0;
        if (forceReveal) {
            revealAlpha = 1.0;
        } else {
            revealAlpha = (player.id === 0) ?
                this.checkIsOpponentLit(this.players[1], this.players[0], null, null) :
                this.checkIsOpponentLit(this.players[0], this.players[1], null, null);
        }

        const barrelLen = player.radius + 14;
        const bx = player.x + Math.cos(player.angle) * barrelLen;
        const by = player.y + Math.sin(player.angle) * barrelLen;

        if (!isOpponent) {
            // When character is hidden in shadows, set avatar opacity to 20% (stealth ghost appearance)
            this.ctx.globalAlpha = (revealAlpha > 0) ? 1.0 : 0.20;

            // Shadow / Feet
            this.ctx.fillStyle = 'rgba(0,0,0,0.5)';
            this.ctx.beginPath();
            this.ctx.arc(player.x, player.y + 4, player.radius, 0, Math.PI * 2);
            this.ctx.fill();

            // Player Body Circle
            this.ctx.fillStyle = player.color;
            this.ctx.shadowColor = player.color;
            this.ctx.shadowBlur = (revealAlpha > 0) ? 18 : 2;
            this.ctx.beginPath();
            this.ctx.arc(player.x, player.y, player.radius, 0, Math.PI * 2);
            this.ctx.fill();

            // Inner Tactical Ring
            this.ctx.strokeStyle = player.color;
            this.ctx.lineWidth = 2;
            this.ctx.beginPath();
            this.ctx.arc(player.x, player.y, player.radius - 3, 0, Math.PI * 2);
            this.ctx.stroke();

            // Gun Barrel
            this.ctx.strokeStyle = '#ffffff';
            this.ctx.lineWidth = 4;
            this.ctx.lineCap = 'round';
            this.ctx.beginPath();
            this.ctx.moveTo(player.x, player.y);
            this.ctx.lineTo(bx, by);
            this.ctx.stroke();

        } else {
            // Opponent Rendering Logic
            if (revealAlpha <= 0) {
                this.ctx.restore();
                return; // Not visible at all
            }

            const d = Math.min(1.0, dazzleAmount);

            if (d > 0.1) {
                // DAZZLED: enemy sprite disappears completely into the blinding light beam
                const dazzleAlpha = Math.max(0, 1.0 - (d - 0.1) * 2.0); // Rapidly fades to 0
                if (dazzleAlpha <= 0) {
                    this.ctx.restore();
                    return; // Completely hidden
                }
                this.ctx.globalAlpha = revealAlpha * dazzleAlpha;

                // Draw standard normal avatar fading out
                this.ctx.fillStyle = '#0f172a';
                this.ctx.beginPath();
                this.ctx.arc(player.x, player.y, player.radius, 0, Math.PI * 2);
                this.ctx.fill();

                this.ctx.strokeStyle = '#334155';
                this.ctx.lineWidth = 2;
                this.ctx.beginPath();
                this.ctx.arc(player.x, player.y, player.radius - 1, 0, Math.PI * 2);
                this.ctx.stroke();

                this.ctx.restore();
                return;
            } else {
                // Normal opponent rendering (no dazzle)
                this.ctx.globalAlpha = revealAlpha;

                // Draw pure black body (like decor)
                this.ctx.fillStyle = '#0f172a';
                this.ctx.shadowBlur = 0;
                this.ctx.beginPath();
                this.ctx.arc(player.x, player.y, player.radius, 0, Math.PI * 2);
                this.ctx.fill();

                // Outline matches the walls/obstacles color
                this.ctx.strokeStyle = '#334155';
                this.ctx.lineWidth = 2;
                this.ctx.beginPath();
                this.ctx.arc(player.x, player.y, player.radius, 0, Math.PI * 2);
                this.ctx.stroke();

                // Dark Gun Barrel
                this.ctx.strokeStyle = '#334155';
                this.ctx.lineWidth = 4;
                this.ctx.lineCap = 'round';
                this.ctx.beginPath();
                this.ctx.moveTo(player.x, player.y);
                this.ctx.lineTo(bx, by);
                this.ctx.stroke();
            }
        }

        // Muzzle Flash Light Flare (Star burst)
        if (player.lastMuzzleFlash > 2.0) {
            const flashRatio = (player.lastMuzzleFlash - 2.0) / 0.5;
            this.ctx.save();
            this.ctx.translate(bx, by);

            // Outer glow
            this.ctx.fillStyle = `rgba(255, 234, 0, ${flashRatio * 0.4})`;
            this.ctx.shadowColor = '#ffea00';
            this.ctx.shadowBlur = 30 * flashRatio;
            this.ctx.beginPath();
            this.ctx.arc(0, 0, 12 + 16 * flashRatio, 0, Math.PI * 2);
            this.ctx.fill();

            // 4-point star burst
            this.ctx.fillStyle = '#fff7b8';
            this.ctx.shadowBlur = 20 * flashRatio;
            this.ctx.beginPath();
            const starSize = (8 + 14 * flashRatio);
            const starInner = starSize * 0.3;
            for (let i = 0; i < 8; i++) {
                const a = (i / 8) * Math.PI * 2 + player.angle;
                const r = i % 2 === 0 ? starSize : starInner;
                if (i === 0) this.ctx.moveTo(Math.cos(a) * r, Math.sin(a) * r);
                else this.ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r);
            }
            this.ctx.closePath();
            this.ctx.fill();

            // White hot center
            this.ctx.fillStyle = '#ffffff';
            this.ctx.shadowBlur = 0;
            this.ctx.beginPath();
            this.ctx.arc(0, 0, 3 * flashRatio, 0, Math.PI * 2);
            this.ctx.fill();

            this.ctx.restore();
        }

        if (!isOpponent) {
            // Reset globalAlpha to 1.0 for name tag and health bar so text stays clear
            this.ctx.globalAlpha = 1.0;

            // Player Name Tag & Health Bar Overlay
            this.ctx.shadowBlur = 0;
            this.ctx.font = 'bold 11px Orbitron, sans-serif';
            this.ctx.fillStyle = '#ffffff';
            this.ctx.textAlign = 'center';
            this.ctx.fillText(player.name, player.x, player.y - player.radius - 12);

            // Health bar above head
            const barW = 36;
            const barH = 4;
            const barX = player.x - barW / 2;
            const barY = player.y - player.radius - 8;

            this.ctx.fillStyle = 'rgba(0,0,0,0.6)';
            this.ctx.fillRect(barX, barY, barW, barH);
            this.ctx.fillStyle = player.hp > 50 ? '#00ff88' : '#ff0055';
            this.ctx.fillRect(barX, barY, (player.hp / 100) * barW, barH);
        }

        this.ctx.restore();
    }

    renderHUD() {
        // P1 Stats
        document.getElementById('p1-hp').style.width = `${Math.max(0, this.players[0].hp)}%`;
        document.getElementById('p1-score').textContent = this.players[0].score;

        const p1CdRatio = 1 - (this.players[0].shootCooldown / this.players[0].maxCooldown);
        document.getElementById('p1-cd-path').setAttribute('stroke-dasharray', `${p1CdRatio * 100}, 100`);
        document.getElementById('p1-cd-text').textContent = p1CdRatio >= 1 ? 'PRÊT' : `${(this.players[0].shootCooldown).toFixed(1)}s`;

        const p1LightInd = document.getElementById('p1-light-indicator');
        p1LightInd.className = `indicator-box ${this.players[0].flashlightOn ? 'light-on' : 'light-off'}`;

        const isP1Revealed = this.checkIsOpponentLit(this.players[1], this.players[0], null, null);
        const p1StealthInd = document.getElementById('p1-stealth-indicator');
        if (p1StealthInd) {
            p1StealthInd.className = `indicator-box ${isP1Revealed ? 'stealth-revealed' : 'stealth-hidden'}`;
            p1StealthInd.querySelector('.indicator-icon').textContent = isP1Revealed ? '👁️' : '🥷';
            p1StealthInd.querySelector('.indicator-text').textContent = isP1Revealed ? 'DÉVOILÉ' : 'CACHÉ';
        }

        // P2 Stats
        document.getElementById('p2-hp').style.width = `${Math.max(0, this.players[1].hp)}%`;
        document.getElementById('p2-score').textContent = this.players[1].score;

        const p2CdRatio = 1 - (this.players[1].shootCooldown / this.players[1].maxCooldown);
        document.getElementById('p2-cd-path').setAttribute('stroke-dasharray', `${p2CdRatio * 100}, 100`);
        document.getElementById('p2-cd-text').textContent = p2CdRatio >= 1 ? 'PRÊT' : `${(this.players[1].shootCooldown).toFixed(1)}s`;

        const p2LightInd = document.getElementById('p2-light-indicator');
        p2LightInd.className = `indicator-box ${this.players[1].flashlightOn ? 'light-on' : 'light-off'}`;

        const isP2Revealed = this.checkIsOpponentLit(this.players[0], this.players[1], null, null);
        const p2StealthInd = document.getElementById('p2-stealth-indicator');
        if (p2StealthInd) {
            p2StealthInd.className = `indicator-box ${isP2Revealed ? 'stealth-revealed' : 'stealth-hidden'}`;
            p2StealthInd.querySelector('.indicator-icon').textContent = isP2Revealed ? '👁️' : '🥷';
            p2StealthInd.querySelector('.indicator-text').textContent = isP2Revealed ? 'DÉVOILÉ' : 'CACHÉ';
        }

        // Timer with urgency colors
        const mins = Math.floor(Math.max(0, this.roundTimer) / 60);
        const secs = Math.floor(Math.max(0, this.roundTimer) % 60);
        const timerEl = document.getElementById('round-timer');
        timerEl.textContent = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;

        if (this.roundTimer <= 10) {
            timerEl.style.color = '#ff0055';
            timerEl.style.textShadow = '0 0 15px rgba(255, 0, 85, 0.8)';
            timerEl.classList.add('timer-critical');
        } else if (this.roundTimer <= 30) {
            timerEl.style.color = '#ffb700';
            timerEl.style.textShadow = '0 0 10px rgba(255, 183, 0, 0.5)';
            timerEl.classList.remove('timer-critical');
        } else {
            timerEl.style.color = '#ffffff';
            timerEl.style.textShadow = 'none';
            timerEl.classList.remove('timer-critical');
        }

        document.getElementById('round-counter').textContent = `ROUND ${this.currentRound}`;

        // Ghost HP bars
        const p1GhostBar = document.getElementById('p1-hp-ghost');
        if (p1GhostBar) p1GhostBar.style.width = `${Math.max(0, this.players[0].ghostHp)}%`;
        const p2GhostBar = document.getElementById('p2-hp-ghost');
        if (p2GhostBar) p2GhostBar.style.width = `${Math.max(0, this.players[1].ghostHp)}%`;

        // HP bar low health pulse
        const p1HpWrap = document.querySelector('#p1-hud .health-bar-wrap');
        const p2HpWrap = document.querySelector('#p2-hud .health-bar-wrap');
        if (p1HpWrap) p1HpWrap.classList.toggle('hp-critical', this.players[0].hp > 0 && this.players[0].hp <= 30);
        if (p2HpWrap) p2HpWrap.classList.toggle('hp-critical', this.players[1].hp > 0 && this.players[1].hp <= 30);

        // Score animation
        const p1ScoreEl = document.getElementById('p1-score');
        const p2ScoreEl = document.getElementById('p2-score');
        if (this.scoreAnimP1 > 0) {
            p1ScoreEl.style.transform = `scale(${1 + this.scoreAnimP1 * 0.3})`;
            p1ScoreEl.style.color = '#00ff88';
            p1ScoreEl.style.textShadow = '0 0 12px rgba(0, 255, 136, 0.6)';
        } else {
            p1ScoreEl.style.transform = 'scale(1)';
            p1ScoreEl.style.color = '#fff';
            p1ScoreEl.style.textShadow = 'none';
        }
        if (this.scoreAnimP2 > 0) {
            p2ScoreEl.style.transform = `scale(${1 + this.scoreAnimP2 * 0.3})`;
            p2ScoreEl.style.color = '#00ff88';
            p2ScoreEl.style.textShadow = '0 0 12px rgba(0, 255, 136, 0.6)';
        } else {
            p2ScoreEl.style.transform = 'scale(1)';
            p2ScoreEl.style.color = '#fff';
            p2ScoreEl.style.textShadow = 'none';
        }

        // Kill feed rendering
        this.renderKillFeed();
    }

    loop(timestamp) {
        const dt = Math.min(0.05, (timestamp - this.lastTime) / 1000);
        this.lastTime = timestamp;

        this.update(dt);
        this.render();

        requestAnimationFrame((t) => this.loop(t));
    }

    addKillFeedEntry(text, color) {
        this.killFeedEntries.push({ text, color, life: 3.0 });
        if (this.killFeedEntries.length > 5) this.killFeedEntries.shift();
    }

    renderKillFeed() {
        const container = document.getElementById('kill-feed');
        if (!container) return;

        container.innerHTML = '';
        for (let i = 0; i < this.killFeedEntries.length; i++) {
            const entry = this.killFeedEntries[i];
            const el = document.createElement('div');
            el.className = 'kill-feed-entry';
            el.textContent = entry.text;
            el.style.color = entry.color;
            el.style.borderLeftColor = entry.color;
            el.style.opacity = Math.min(1, entry.life);
            if (entry.life > 2.5) {
                el.style.transform = `translateY(${(1 - (3 - entry.life) * 2) * -20}px)`;
            }
            container.appendChild(el);
        }
    }
}

// Launch Game on Window Load
window.addEventListener('DOMContentLoaded', () => {
    window.gameInstance = new CandelaGame();
});
