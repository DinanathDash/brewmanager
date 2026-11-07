## [1.1.0] - 2026-11-06

- Updated shelf widget for DroppyKit 1.22.0 notch-wrap support beside the camera notch and island pill, with adjusted content height (136pt) to eliminate clipping.
- Added dedicated Package Details settings page with top hero heading, formula/cask badges, caveats right after overview, right-aligned action buttons, and full installation metadata ("Installed on", "Install reason", and "Installed size").
- Added interactive dependencies and dependents chip navigation with seamless back navigation stack.
- Enabled version upgrade paths (`installed → current`) by default for all outdated packages.
- Streamlined package list rows by removing inline update/delete buttons in favor of the detail view and clean chevron indicators.
- Preserved active tab selection (Installed vs Discover) when navigating back from package details.
- Fixed update state persistence so packages upgraded from the details page immediately update in memory and clear their outdated status.
- Added rotating file logging (`~/Library/Logs/Brewmanager/brewmanager.log`) with size and age auto-purge, and non-modal log export (`panel.begin`) to avoid main thread hang warnings.
- Compacted HUD notifications with tight padding to eliminate dead vertical space.

## [1.0.1] - 2026-09-24

- Added settings to view and manage installed Homebrew packages.
- Added a package search to discover and install new Formulae and Casks.
- Included a shelf widget to monitor Homebrew status at a glance.
- Added an interactive HUD for quick status updates.
- Added clear UI badges to distinguish between Formulae and Casks.
- Included a one-click action to keep all Homebrew packages up to date.

## [1.0.0] - 2026-09-22

- Basic package viewing and management.
- Initial DroppyKit integration with shelf widget.
- Settings pane for Homebrew configuration.
