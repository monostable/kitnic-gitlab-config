/**
 * Renders a terminal button to open a web terminal.
 * Used in environments table.
 */
const Vue = require('vue');
const terminalIconSvg = require('icons/_icon_terminal.svg');

module.exports = Vue.component('terminal-button-component', {
  props: {
    terminalPath: {
      type: String,
      default: '',
    },
  },

  data() {
    return { terminalIconSvg };
  },

  template: `
    <a class="btn terminal-button"
      :href="terminalPath">
      ${terminalIconSvg}
    </a>
  `,
});
