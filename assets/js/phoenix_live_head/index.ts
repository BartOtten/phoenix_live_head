module PhxLiveHead {
  // TYPES
  type action = "s" | "a" | "x" |"b" |"r" | "t" | "i" | "d";
  type attr = string;
  type value = string;
  type query = string;
  type change = [action, attr, value]
  type detail = {"c": [[query, change[]]]}
  type state = { [key: attr]: string | null}

  // CONSTANTS
  export const NAMESPACE: string = 'plh';
  const ALL_ATTR: string = '*';
  const CLASS_ATTR: string = "class";
  const ATTR: { [key: string]: string } = { "c": CLASS_ATTR, "h": "href" }
  const QUERY: { [key: string]: string } = { "f": "link[rel*='icon']" }

  // HELPERS
  function camelToKebabCase(s: string): string { return s.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase(); }
  function stateKey(key: string, el: HTMLElement): string { return `${NAMESPACE}:${el.dataset['id']}-${key}`; }
  function randId(): string {
  return Math.floor((1 + Math.random()) * 0x10000)
      .toString(16)
      .substring(1);
}
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

  function setDynamicAttributes(el: HTMLElement, replacements: {[key: string]: string}){
    for(const [dynKey, dynTempl] of Object.entries(el.dataset).filter(([key, _]) => key.startsWith('dynamic'))) {
      const attr = camelToKebabCase(dynKey.substring("dynamic".length))
      if(dynTempl === undefined){return;}
      if(Object.keys(replacements).some(replacement => dynTempl?.includes(`{${replacement}}`))){
        const newValue: string = dynTempl?.replace(
          /{(\w+)}/g,
          (placeholderWithDelimiters, placeholderWithoutDelimiters) =>
            replacements.hasOwnProperty(placeholderWithoutDelimiters) ?
              replacements[placeholderWithoutDelimiters] : sessionStorage.getItem(stateKey('dyn-' + placeholderWithoutDelimiters, el)) || `[!value for ${placeholderWithDelimiters} not found!]`
        );

        el.setAttribute(attr, newValue)
      }
    }
  }

  function applyToElement(el: HTMLElement, changes: change[]) {
    let replacements = {}

    changes.forEach(function (change: change) {
      const [action, attr_input, value] = change;
      const attr = ATTR[attr_input] || attr_input

      // we collect all replacements so we can set them all at once
      // as there might be multiple in a single attribute
      if (action === "d") {
        replacements = {[attr]: value, ...replacements};
        sessionStorage.setItem(stateKey('dyn-' + attr, el), value);
        return;
        // the replacement takes place before any other action
      } else if (Object.keys(replacements).length > 0) {
        setDynamicAttributes(el, replacements);
        replacements = []
      }

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
          default: null
        }
      }
    }
    );

    // execute remaining replacements when there was no
    // subsequent action
    if (Object.keys(replacements).length > 0) {
        setDynamicAttributes(el, replacements);
    }

  };

  export function main(event: Event): void {
    const detail: detail = (event as CustomEvent).detail;
    // the list of [query, changes] is sent in reverse, due to prepending items
    for (const [query_input, changes_input] of detail.c.reverse()) {
      const query = QUERY[query_input] || query_input
      const elements = document.querySelectorAll(query);
      // the list of changes is sent in reverse, due to prepending items
      const changes = changes_input.reverse()

      elements.forEach(el => {
        const tel = el as HTMLElement;
        if(!tel.dataset['id']){tel.dataset['id'] = randId()}
        if (!isStateBackupped(tel, ALL_ATTR, 'orig')) { backupState(tel, ALL_ATTR, 'orig') }

        applyToElement(tel, changes)
      })
    }
  }
}

// clear session keys of Phoenix Live Head
Object.keys(sessionStorage).forEach(key => key.startsWith(PhxLiveHead.NAMESPACE) && sessionStorage.removeItem(key))

window.addEventListener("phx:hd", (event: Event) => {
  PhxLiveHead.main(event);
});
