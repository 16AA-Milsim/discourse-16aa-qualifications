import Component from "@glimmer/component";

export default class QualificationCellComponent extends Component {
  get cellClass() {
    const base = "qualification-cell";
    const extra = this.args.cellClass;

    return extra ? `${base} ${extra}` : base;
  }
}
