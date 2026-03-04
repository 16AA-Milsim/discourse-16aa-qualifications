import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

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
      let allowed =
        (siteSettings.sixteen_aa_qualifications_allowed_groups || "")
          .split("|")
          .map((g) => g.trim())
          .filter(Boolean);

      if (allowed.length === 0) {
        const fallback = (siteSettings.sixteen_aa_qualifications_member_group_name || "").trim();
        allowed = fallback ? [fallback] : [];
      }

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
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");

      if (!siteSettings?.sixteen_aa_qualifications_enabled) {
        return;
      }

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
            return i18n("sixteen_aa_qualifications.nav_link");
          }

          get text() {
            return i18n("sixteen_aa_qualifications.nav_link");
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
