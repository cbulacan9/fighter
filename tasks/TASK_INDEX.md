# Implementation Task Index

## Overview
Tasks are organized in phases and should be completed in order. Each task builds on previous work.

**Reference Documents:**
- `/docs/ARCHITECTURE.md` - System overview, scene hierarchy, file structure
- `/docs/SYSTEMS.md` - Detailed system specifications
- `/docs/CHARACTERS.md` - Character design reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` - Character systems implementation proposal

---

## Phase 1: Project Foundation
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 001 | Project Setup | None | Complete |
| 002 | Data Resources | 001 | Complete |

## Phase 2: Core Grid & Tiles
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 003 | Tile Entity | 002 | Complete |
| 004 | Grid System | 003 | Complete |
| 005 | Board Manager | 004 | Complete |

## Phase 3: Input & Movement
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 006 | Input Handler | 005 | Complete |
| 007 | Row/Column Shifting | 006 | Complete |
| 008 | Snap-Back Animation | 007 | Complete |

## Phase 4: Match & Cascade
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 009 | Match Detector | 005 | Complete |
| 010 | Tile Spawner | 003 | Complete |
| 011 | Cascade Handler | 009, 010 | Complete |

## Phase 5: Combat
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 012 | Fighter State | 002 | Complete |
| 013 | Combat Manager | 011, 012 | Complete |

## Phase 6: AI
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 014 | AI Controller | 009, 013 | Complete |

## Phase 7: UI
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 015 | HUD (Health Bars) | 012 | Complete |
| 016 | Damage Numbers | 013 | Complete |
| 017 | Stun Overlay | 013 | Complete |
| 018 | Game Overlays | 001 | Complete |
| 019 | Stats Screen | 013 | Complete |

## Phase 8: Integration
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 020 | Game Manager | All above | Complete |
| 021 | Main Scene Integration | 020 | Complete |

## Bug Fixes
| Task | Name | Dependencies | Status | Priority |
|------|------|--------------|--------|----------|
| 022 | Fix Tile Display | 003 | Complete | Critical |
| 023 | Debug Board Initialization | 022 | Complete | Critical |
| 024 | Fix Initial State Transition | 023 | Complete | Critical |
| 025 | Fix Drag Input State | 024 | Complete | Critical |
| 026 | Fix Drag Cleanup | 025 | Complete | Critical |

---

## Phase 9: Character Systems - Status Effects
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 028 | Status Effect Data & Types | 002 | Pending |
| 029 | Status Effect Manager | 028 | Pending |
| 030 | Status Effect Integration | 029, 013 | Pending |
| 031 | Status Effect UI | 030, 015 | Pending |
| 032 | Status Effect Tests | 030 | Pending |

## Phase 10: Character Systems - Mana System
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 033 | Mana Config & Data | 002 | Pending |
| 034 | Mana System Core | 033, 012, 013 | Pending |
| 035 | Mana UI Components | 034, 015 | Pending |
| 036 | Mana System Tests | 034 | Pending |

## Phase 11: Character Systems - Clickable Tiles
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 037 | Tile Data Extension | 003, 002 | Pending |
| 038 | Click Input Handler | 037, 006 | Pending |
| 039 | Click Activation Flow | 038, 030, 034 | Pending |
| 040 | Clickable Tiles Tests | 039 | Pending |

## Phase 12: Character Systems - Combo Sequences
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 041 | Sequence Pattern Data | 002 | Pending |
| 042 | Sequence Tracker | 041, 009 | Pending |
| 043 | Sequence UI Indicator | 042, 015 | Pending |
| 044 | Sequence System Tests | 042 | Pending |

## Phase 13: Character Framework
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 045 | Character Data Resource | 033, 041, 037 | Pending |
| 046 | Character Loading & Selection | 045, 020 | Pending |
| 047 | Basic Starter Character | 045, 046 | Pending |
| 048 | Unlock System | 046 | Pending |

## Phase 14: Hunter Character
| Task | Name | Dependencies | Status |
|------|------|--------------|--------|
| 049 | Hunter Character Data | 045, 041 | Pending |
| 050 | Pet Tile Implementation | 049, 038, 042 | Pending |
| 051 | Hunter Abilities (Bear/Hawk/Snake) | 050, 030, 039 | Pending |
| 052 | Alpha Command Ultimate | 051, 034 | Pending |
| 053 | Hunter AI Support | 052, 014 | Pending |

---

## Task Status Legend
- **Pending** - Not started
- **In Progress** - Currently being worked on
- **Complete** - Finished and tested
- **Blocked** - Waiting on dependency or issue
