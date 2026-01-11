# Implementation Task Index

## Overview
Tasks are organized in phases and should be completed in order. Each task builds on previous work.

**Reference Documents:**
- `/docs/ARCHITECTURE.md` - System overview, scene hierarchy, file structure
- `/docs/SYSTEMS.md` - Detailed system specifications

---

## Phase 1: Project Foundation
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 001 | Project Setup | None | Complete |
| 002 | Data Resources | 001 | Complete |

## Phase 2: Core Grid & Tiles
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 003 | Tile Entity | 002 | Pending |
| 004 | Grid System | 003 | Pending |
| 005 | Board Manager | 004 | Pending |

## Phase 3: Input & Movement
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 006 | Input Handler | 005 | Pending |
| 007 | Row/Column Shifting | 006 | Pending |
| 008 | Snap-Back Animation | 007 | Pending |

## Phase 4: Match & Cascade
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 009 | Match Detector | 005 | Pending |
| 010 | Tile Spawner | 003 | Pending |
| 011 | Cascade Handler | 009, 010 | Pending |

## Phase 5: Combat
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 012 | Fighter State | 002 | Pending |
| 013 | Combat Manager | 011, 012 | Pending |

## Phase 6: AI
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 014 | AI Controller | 009, 013 | Pending |

## Phase 7: UI
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 015 | HUD (Health Bars) | 012 | Pending |
| 016 | Damage Numbers | 013 | Pending |
| 017 | Stun Overlay | 013 | Pending |
| 018 | Game Overlays | 001 | Pending |
| 019 | Stats Screen | 013 | Pending |

## Phase 8: Integration
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 020 | Game Manager | All above | Pending |
| 021 | Main Scene Integration | 020 | Pending |

---

## Task Status Legend
- **Pending** - Not started
- **In Progress** - Currently being worked on
- **Complete** - Finished and tested
- **Blocked** - Waiting on dependency or issue
