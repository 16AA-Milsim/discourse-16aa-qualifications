import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class QualificationsRoute extends Route {
  model() {
    return ajax("/qualifications.json").catch((error) => {
      if (error?.jqXHR?.status === 403) {
        this.router.transitionTo("discovery.latest");
      }
      throw error;
    });
  }
}
