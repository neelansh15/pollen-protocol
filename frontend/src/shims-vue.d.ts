/* eslint-disable */
declare module '*.vue' {
  import type { DefineComponent, DefineComponent } from 'vue';
  const component: DefineComponent<{}, {}, any>;
  export default component;
}

declare module 'vue-virtual-scroller' {
  export const DynamicScroller: DefineComponent<{}, {}, any>;
}
