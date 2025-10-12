import { withPluginApi } from "discourse/lib/plugin-api";
import applyQualificationColours from "../lib/qualification-cell-colours";

export default {
  name: "16aa-qualification-cell-colours",

  initialize() {
    if (window.__qualificationCellColoursInitialized) {
      return;
    }

    window.__qualificationCellColoursInitialized = true;

    withPluginApi("1.20.0", (api) => {
      api.decorateCookedElement(
        (root) => applyQualificationColours(root),
        { onlyStream: false }
      );
    });
  },
};
