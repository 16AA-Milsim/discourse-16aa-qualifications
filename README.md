# Discourse 16AA Qualifications Plugin

## TODO
- Add default fallback plugin settings json strings.
- Implement some method so loading doesnt take so long when there are many users to display/search through.
- Fix the wide CIC column that occurs sometimes.
- Doesn't switch between light and dark mode until page is refreshed.

This plugin provides a consolidated qualifications roster for members of the 16AA community. It exposes a `/qualifications` page that lists every member of the configured base group and displays their earned qualifications grouped by category.

## Features

- Pulls user data directly from the configured Discourse group (default: `16AA_Member`).
- Prioritises members into sections based on a configurable ordered group hierarchy.
- Shows the highest qualification earned for each category, with colour-coded empty states when none are present.
- Includes support for standalone qualifications outside of grouped hierarchies.
- Adds an admin interface at `/admin/plugins/16aa-qualifications` for editing the group priority list and qualification definitions.
- Respects visibility and access options controlled via plugin site settings.

## Configuration

After installing the plugin:

1. Visit **Admin → Settings → Plugins** and search for “16AA qualifications” to adjust visibility options and the base group if required.
2. Navigate to **Admin → Plugins → 16AA Qualifications** to edit the group priority list, qualification groups, and standalone qualifications. The editor accepts JSON arrays matching the default seed file located at `config/qualification_defaults.yml`.
3. Ensure user badges exist for each qualification name referenced in the configuration so the roster can detect earned awards.

The public roster is available at `/qualifications` for any user that meets the configured visibility requirements. The navigation link appears automatically for eligible users.
