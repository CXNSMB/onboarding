## ⚠️ Merge Conflict Resolution

**Important**: This PR contains a `.devcontainer/` directory conflict that needs to be resolved during merge:

### Conflict Details
- **Main branch**: `.devcontainer/` directory was intentionally removed 
- **Dev branch**: Contains `.devcontainer/` for development environment

### Resolution Strategy
When merging this PR:
1. **Keep main branch behavior**: ✅ Remove `.devcontainer/` from main
2. **Preserve dev setup**: ✅ Keep `.devcontainer/` only in dev branch  
3. **Conflict resolution**: Choose "delete `.devcontainer/`" during merge

This maintains the intended architecture where:
- **Main branch**: Clean, production-ready (no dev container setup)
- **Dev branch**: Full development environment with container setup

## 🎯 Summary
This PR brings the complete and production-ready Azure OIDC setup script from dev to main branch. The script now supports all advanced scenarios including Microsoft Graph API permissions, REST API consent, and improved reliability.

## 🚀 Key Features Added

### ✅ Microsoft Graph API Permissions
- **Application.ReadWrite.All**: Service Principal can manage application registrations
- **Directory.ReadWrite.All**: Service Principal can write directory objects  
- Supports Application Administrator and Directory Writers functionality

### ✅ Improved Admin Consent
- **REST API First**: Always uses REST API for app permissions consent (Cloud Shell compatible)
- **Removed Azure CLI Fallback**: Eliminates delegated vs app permissions confusion
- **Idempotent**: Handles existing permissions gracefully

### ✅ Enhanced Script Features
- **Default repo**: Uses `solution-onboarding` as default app name
- **Verbose mode**: Detailed logging with `verbose` parameter
- **Management group support**: Create/use management groups with `management-group` parameter
- **Security conditions**: Owner role with restrictions (cannot assign Owner/RBAC Admin roles)
- **Robust error handling**: Multiple retry mechanisms and fallbacks

## 🔧 Technical Improvements

### App Permissions Consent Fix
- Uses `appRoleAssignments` endpoint instead of `oauth2PermissionGrants`
- Ensures proper **app permissions** consent (not delegated permissions)
- Works reliably in all Azure environments including Cloud Shell

### Idempotency & Reliability
- Checks for existing resources before creating new ones
- Handles Azure CLI JSON decoding errors
- Multiple fallback methods for Service Principal creation
- Better error messages and troubleshooting guidance

### Usage Documentation
- Updated comments with both main and dev branch URLs
- Clear examples for all usage scenarios
- Comprehensive README updates

## 📋 Commits Included

1. **feat: Complete Azure OIDC onboarding script with Microsoft Graph permissions** (fda1e5f)
   - Added Microsoft Graph API permissions support
   - Implemented management group functionality
   - Enhanced RBAC with security conditions

2. **fix: Improve admin consent with REST API fallback** (fab4d00)
   - Added REST API consent method
   - Improved error handling for consent operations

3. **Fix app permissions consent: Always use REST API for app role assignments** (4693c9f)
   - Removed Azure CLI fallback for consent
   - Ensures proper app permissions (not delegated permissions)
   - Tested in Cloud Shell environment

4. **Update usage comments: Add both main and dev branch URLs** (a202dbf)
   - Clear documentation for production vs development usage
   - Updated usage examples

## 🧪 Testing
- ✅ Full script tested in real Azure environment
- ✅ App permissions consent verified via Azure Portal
- ✅ Idempotency tested with repeated runs
- ✅ Management group creation/usage tested
- ✅ Verbose mode logging verified
- ✅ Cloud Shell compatibility confirmed

## 🔒 Security
- Service Principal has Owner role with security conditions
- **Cannot assign/delete**: Owner and RBAC Administrator roles
- Microsoft Graph permissions follow principle of least privilege
- All permissions are properly consented as app permissions

## 📚 Documentation
- README.md updated with all new features
- Usage examples for all scenarios
- Troubleshooting guidance included
- Clear parameter documentation

## 🎯 Breaking Changes
None - all changes are backward compatible and additive.

## 📝 Post-Merge Actions
After merging to main:
1. The main branch will have the complete, production-ready script
2. Users can use the main branch URL for stable production deployments
3. The dev branch remains available for future development

---

**Ready for production use!** 🚀
This script now handles all Azure OIDC onboarding scenarios with enterprise-grade reliability and security.
