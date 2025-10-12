import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "I18n";

const PLUGIN_API_VERSION = "1.20.0";

function canViewRoster(siteSettings, currentUser) {
  if (!siteSettings?.sixteen_aa_qualifications_enabled) {
    return false;
  }

  const visibility = siteSettings.sixteen_aa_qualifications_visibility;

  if (visibility === "everyone") {
    return true;
  }

  if (!currentUser) {
    return false;
  }

  if (currentUser.staff) {
    return true;
  }

  switch (visibility) {
    case "staff":
      return false;
    case "trust_level_2":
      return currentUser.trust_level >= 2;
    case "trust_level_3":
      return currentUser.trust_level >= 3;
    case "trust_level_4":
      return currentUser.trust_level >= 4;
    case "groups": {
      const allowed =
        (siteSettings.sixteen_aa_qualifications_allowed_groups || "")
          .split("|")
          .map((g) => g.trim())
          .filter(Boolean);

      if (allowed.length === 0) {
        return false;
      }

      const userGroups = currentUser.groups || [];
      return userGroups.some((group) => allowed.includes(group.name));
    }
    default:
      return false;
  }
}

export default {
  name: "16aa-qualifications-nav",

  initialize() {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      const siteSettings = api.container.lookup("service:site-settings");

      if (!siteSettings?.sixteen_aa_qualifications_enabled) {
        return;
      }

      const condition = () => canViewRoster(siteSettings, api.getCurrentUser());

      api.addNavigationBarItem({
        name: "qualifications",
        displayName: I18n.t("sixteen_aa_qualifications.nav_link"),
        href: "/qualifications",
        customFilter: condition,
      });

      api.addCommunitySectionLink((BaseCommunitySectionLink) => {
        return class extends BaseCommunitySectionLink {
          get name() {
            return "qualifications";
          }

          get route() {
            return "qualifications";
          }

          get currentWhen() {
            return "qualifications";
          }

          get title() {
            return I18n.t("sixteen_aa_qualifications.nav_link");
          }

          get text() {
            return I18n.t("sixteen_aa_qualifications.nav_link");
          }

          get prefixValue() {
            return "id-card-clip";
          }

          get shouldDisplay() {
            return canViewRoster(this.siteSettings, this.currentUser);
          }
        };
      });
    });
  },
};
