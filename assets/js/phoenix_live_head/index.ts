window.addEventListener("phx:hd", (event: Event) => {

  // TYPES
  type action = "s" | "a" | "x" |"b" |"r" | "t" | "i" | "d";
  type attr = string;
  type value = string;
  type query = string;
  type change = [action, attr, value]
  type detail = {"c": [[query, change[]]]}
  type state = { [key: attr]: string | null}

  // CONSTANTS
  const ALL_ATTR: string = '*';
  const CLASS_ATTR: string = "class";
  const ATTR: { [key: string]: string } = { "c": CLASS_ATTR, "h": "href" }
  const QUERY: { [key: string]: string } = { "f": "link[rel*='icon']" }

  // HELPERS
  function kebabToCamelCase(s: string): string { return s.replace(/-./g, x => x[1].toUpperCase()); }
  function stateKey(key: string, el: HTMLElement): string { return `${el.id}-${key}`; }
  function attrObject(el: HTMLElement): state {
    return Array.from(el.attributes)
      .filter(a => a.specified)
      .map(a => ({[a.nodeName]: a.nodeValue}))
      .reduce((prev, curr) => Object.assign(prev || {}, curr))
  }

  function isStateBackupped(el: HTMLElement, attr: string, key: string): boolean {
    const saved = getState(el, key)
    if(saved !== undefined && attr === ALL_ATTR){ return true}
    if(saved !== undefined && attr !== ALL_ATTR){ return saved[attr] !== undefined }

    return false
  }

  function getState(el: HTMLElement, key: string): state | undefined {
    const value = sessionStorage.getItem(stateKey(key, el)) || null
    return value !== (undefined  || null) ? JSON.parse(value) : undefined
  }

  function saveState(el: HTMLElement, key: string, value: object): void {
    return sessionStorage.setItem(stateKey(key, el), JSON.stringify(value))
  }


  function backupState(el: HTMLElement, attr: string, key: string): void {
    const attrs = attrObject(el)

    if(attr !== ALL_ATTR){ return saveState(el, key, {[attr]: attrs[attr]}); }

    saveState(el, key, attrs);
  }

  function restoreState(el: HTMLElement, attr: string, key: string): void {
    const state = getState(el, key)

    if(state === undefined) {
      console.warn(`No state backup found for key ${stateKey(key, el)}`)
    } else {
      if(attr !== ALL_ATTR){ return restoreAttrState(el, attr, key) }

      for(const attr of Object.keys(state)) {
        restoreAttrState(el, attr, key)
      }}
  }

  function restoreAttrState(el: HTMLElement, attr: attr, key: string): void {
    const state = getState(el, key)

    if(state === undefined) {
      console.warn(`No state backup found for key ${stateKey(key, el)}`)
    } else {
      const value = state[attr]

      if (value !== (undefined || null)) {
        attr === CLASS_ATTR ? el.className = value : el.setAttribute(attr, value);
      }
    }
  }

  function setDynamicAttribute(el: HTMLElement, attr: attr, value: value): void {
    const dynAttr = kebabToCamelCase(`dynamic-${attr}`)
    const dynParts = el.dataset[dynAttr]?.split("{dynamic}", 2)

    if (!dynParts) { throw 'No dynamic scheme set'; }

    if (dynParts.length == 1) {
      const [prefix] = dynParts
      el.setAttribute(attr, `${prefix}${value}`)
    } else if (dynParts.length === 2) {
      const [prefix, suffix] = dynParts
      el.setAttribute(attr, `${prefix}${value}${suffix}`)
    }
  }


  function applyToElement(el: HTMLElement, changes: change[]) {
    changes.forEach(function (change: change) {
      const [action, attr_input, value] = change;
      const attr = ATTR[attr_input] || attr_input

      if (attr === CLASS_ATTR) {
        switch (action) {
          case "s": el.className = value; break;
          case "a": el.classList.add(value); break;
          case "x": el.classList.remove(value); break;
          case "t": el.classList.toggle(value); break;
          case "b": backupState(el, attr_input, value); break;
          case "r": restoreState(el, attr, value); break;
          case "i": restoreState(el, attr, 'orig'); break;
          default: null
        }
      } else {
        switch (action) {
          case "s": el.setAttribute(attr, value); break;
          case "x": el.removeAttribute(attr); break;
          case "b": backupState(el, attr_input, value); break;
          case "r": restoreState(el, attr, value); break;
          case "i": restoreState(el, attr, 'orig'); break;
          case "d": setDynamicAttribute(el, attr, value); break;
          default: null
        }
      }
    }
    );
  };

  function main(event: Event): void {
    const detail: detail = (event as CustomEvent).detail;
    // the list of [query, changes] is sent in reverse, due to prepending items
    for (const [query_input, changes] of detail.c.reverse()) {
      const query = QUERY[query_input] || query_input
      const elements = document.querySelectorAll(query);

      elements.forEach(el => {
        const tel = el as HTMLElement;
        if (!isStateBackupped(tel, ALL_ATTR, 'orig')) { backupState(tel, ALL_ATTR, 'orig') }

        // the list of changes is sent in reverse, due to prepending items
        applyToElement(tel, changes.reverse())
      })
    }
  }

  main(event);
});
