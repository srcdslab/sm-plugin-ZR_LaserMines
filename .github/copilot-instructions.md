# Copilot Instructions for ZR_LaserMines Plugin

## Repository Overview

This repository contains a SourcePawn plugin for SourceMod that implements laser mines functionality for the Zombie:Reloaded mod. The plugin allows human players to plant laser mines that create laser beams to damage zombies and defend positions.

### Key Features
- Laser mine planting and activation system
- Configurable damage, explosion radius, and activation time
- Player limits and pickup functionality
- Translation support for multiple languages
- Comprehensive native API for other plugins
- Integration with Zombie:Reloaded mod

## Technical Environment

### Core Technologies
- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11+ (compatible with 1.12+)
- **Build System**: SourceKnight
- **CI/CD**: GitHub Actions
- **Target Games**: Source engine games with Zombie:Reloaded

### Dependencies
- **SourceMod**: Base scripting platform
- **ZombieReloaded**: Core mod this plugin extends
- **MultiColors**: For colored chat messages
- **SDK Tools & Hooks**: For entity manipulation and game events

### File Structure
```
addons/sourcemod/
├── scripting/
│   ├── ZR_LaserMines.sp           # Main plugin source
│   └── include/
│       └── zr_lasermines.inc      # Native functions API
└── translations/
    └── zr_lasermines.phrases.txt  # Translation phrases
```

## Build Process

### SourceKnight Configuration
The project uses SourceKnight (`sourceknight.yaml`) for building:
- **Project Name**: ZR_LaserMines
- **Output**: `/addons/sourcemod/plugins`
- **Target**: `ZR_LaserMines` (produces ZR_LaserMines.smx)

### Dependencies Resolution
SourceKnight automatically downloads and configures:
- SourceMod 1.11.0-git6917
- ZombieReloaded plugin includes
- MultiColors plugin

### Build Commands
```bash
# Using SourceKnight (preferred)
sourceknight build

# Manual compilation (if SourceKnight unavailable)
spcomp -i"include" ZR_LaserMines.sp
```

### CI/CD Pipeline
GitHub Actions workflow (`.github/workflows/ci.yml`):
1. Builds plugin using SourceKnight action
2. Creates packages with translations
3. Uploads artifacts
4. Creates releases for tags and main branch

## Code Standards & Best Practices

### SourcePawn Conventions
- Use **tabs for indentation** (4 spaces equivalent)
- **camelCase** for local variables and parameters
- **PascalCase** for functions and public variables
- **g_** prefix for global variables
- **#pragma semicolon 1** and **#pragma newdecls required**

### Plugin-Specific Patterns
```sourcepawn
// Global variables pattern
ConVar g_cvSpawnMineAmount;
int g_iAmount;
bool g_bAllowPickup;

// Event handling pattern
public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    // Implementation
}

// Native function pattern
public int Native_AddMines(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int amount = GetNativeCell(2);
    // Implementation
}
```

### Memory Management
- Use `delete` for StringMap/ArrayList cleanup (never `.Clear()`)
- No null checks needed before `delete` operations
- Properly handle entity references and cleanup
- Use async SQL operations with methodmaps

### Translation Usage
```sourcepawn
LoadTranslations("zr_lasermines.phrases");
CPrintToChat(client, "%t", "MineAmount", amount);
```

## Development Workflow

### Common Tasks

#### Adding New ConVars
1. Declare global ConVar variable
2. Create ConVar in `OnPluginStart()`
3. Hook changes with `HookConVarChange()`
4. Update values in `OnConfigsExecuted()`

#### Adding New Commands
```sourcepawn
RegConsoleCmd("sm_commandname", Command_Handler, "Description");

public Action Command_Handler(int client, int args)
{
    // Validate client and permissions
    // Implementation
    return Plugin_Handled;
}
```

#### Extending Native API
1. Add native declaration to `zr_lasermines.inc`
2. Create native in `AskPluginLoad2()`
3. Implement native function
4. Update optional natives in include file

### Testing Considerations
- Test on development server with Zombie:Reloaded
- Verify memory usage with SourceMod profiler
- Check for proper entity cleanup on map changes
- Test translation files for all supported languages
- Validate SQL operations for thread safety

### Performance Guidelines
- Cache expensive operations (avoid O(n) in frequently called functions)
- Use entity references efficiently
- Minimize timer usage
- Optimize beam creation and collision detection
- Consider server tick rate impact

## Plugin Architecture

### Core Components

#### Entity Management
- **Laser Mines**: Physical entities placed on walls
- **Laser Beams**: `env_beam` entities creating laser lines
- **Collision Detection**: OnTouchedByEntity hooks

#### Player Data
```sourcepawn
int g_iClientsAmount[MAXPLAYERS+1];        // Current mine count
int g_iClientsMyAmount[MAXPLAYERS+1];      // Player's mines on map
int g_iClientsMaxLimit[MAXPLAYERS+1];      // Custom limits
int g_iUsedByNative[MAXPLAYERS+1];         // Native usage tracking
```

#### Configuration System
ConVars for all adjustable parameters:
- Mine amounts and limits
- Damage values and explosion radius
- Activation timing
- Pickup permissions

### API Design
The plugin provides extensive native functions for other plugins:
- Mine management (add, remove, set amounts)
- Entity queries (check if entity is mine, get owner)
- Force operations (plant without restrictions)
- Event system with forwards for customization

## Troubleshooting

### Common Issues
- **Build Errors**: Ensure all dependencies are properly included
- **Runtime Errors**: Check SourceMod logs for entity cleanup issues
- **Performance**: Monitor entity count and beam creation
- **Compatibility**: Verify ZombieReloaded version compatibility

### Debugging
- Use SourceMod's `sm_dump_admcache` for permission issues
- Check `sm plugins list` for plugin loading status
- Monitor `sm_cvar_debug` for ConVar issues
- Use `sm_entity_dump` for entity debugging

### Validation Checklist
- [ ] Plugin compiles without warnings
- [ ] All natives properly implemented
- [ ] Translation files complete
- [ ] Memory cleanup on map change
- [ ] ConVar validation and bounds checking
- [ ] Proper error handling in all functions

## Integration Points

### ZombieReloaded Integration
- Respects ZR team classifications
- Uses ZR include for team checking
- Integrates with ZR infection mechanics

### MultiColors Integration
- Consistent chat message formatting
- Color scheme matching server theme
- Proper color code usage

### SourceMod Framework
- Standard event handling patterns
- Proper plugin lifecycle management
- Native library registration
- Translation system integration

## Best Practices Summary

1. **Always validate client indices** before operations
2. **Use proper error handling** for all API calls
3. **Implement cleanup** in OnPluginEnd() if necessary
4. **Test thoroughly** with multiple players and scenarios
5. **Follow SourceMod conventions** for code organization
6. **Document complex logic** with clear comments
7. **Use async operations** for all database queries
8. **Optimize for performance** in frequently called functions
9. **Maintain backward compatibility** when possible
10. **Update version numbers** consistently with changes

This plugin serves as a good example of a well-structured SourceMod plugin with proper API design, memory management, and integration with existing mod frameworks.