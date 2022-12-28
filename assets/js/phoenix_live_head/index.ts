window.addEventListener("phx:hd", (event: Event) => {

    // TYPES
    type action = "s" | "a" | "r" | "t" | "i" | "d";
    type attr = string;
    type value = string;
    type query = string;
    type reset = "i"
    type change = [action, attr, value] | reset
    type detail = { [key: query]: change[] | reset}

    // CONSTANTS
    const CLASS_ATTR: string = "class-name";
    const ATTR: { [key: string]: string } = { "c": CLASS_ATTR, "h": "href" }
    const QUERY: { [key: string]: string } = { "f": "link[rel*='icon']" }

    // HELPERS
    function kebabToCamelCase(s: string): string { return s.replace(/-./g, x => x[1].toUpperCase()); }
    function camelToKebabCase(s: string): string { return s.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase(); }
    function origValueKey(attr: string): string { return kebabToCamelCase(`orig-${camelToKebabCase(attr)}`); }
    function isPreserved(el: HTMLElement, attr: string): boolean { return el.dataset[origValueKey(attr)] !== undefined; }

    // ACTIONS
    function preserveAttrValue(el: HTMLElement, attr: string): void {
        const value = el.getAttribute(kebabToCamelCase(attr))
        if (value == null) {
            el.dataset[origValueKey(attr)] = undefined;
        } else {
            el.dataset[origValueKey(attr)] = value;
        }
    }

    function restoreAttrValue(el: HTMLElement, attr: attr): void {
        const value = el.dataset[origValueKey(attr)];

        if (value !== undefined) {
            attr === CLASS_ATTR ? el.className = value : el.setAttribute(attr, value);
        } else {
            throw "Could not restore value: value undefined"
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

    function resetElement(el: HTMLElement) {
        Object.keys(el.dataset).filter(k => k.includes("orig")).forEach(k => {
            const attr = camelToKebabCase(k).replace("orig-", "")
            restoreAttrValue(el, attr)
        });
    }

    function applyToElement(el: HTMLElement, changes: change[]) {
        changes.forEach(function (change: change) {
            const [action, attr_input, value] = change;

            if(action=== "i"){ resetElement(el); return }

            const attr = ATTR[attr_input] || attr_input

            if (!isPreserved(el, attr)) { preserveAttrValue(el, attr) }

            if (attr === CLASS_ATTR) {
                switch (action) {
                    case "s": el.className = value; break;
                    case "a": el.classList.add(value); break;
                    case "r": el.classList.remove(value); break;
                    case "t": el.classList.toggle(value); break;
                    case "i": restoreAttrValue(el, attr); break;
                    default: null
                }
            } else {
                switch (action) {
                    case "s": el.setAttribute(attr, value); break;
                    case "r": el.removeAttribute(attr); break;
                    case "i": restoreAttrValue(el, attr); break;
                    case "d": setDynamicAttribute(el, attr, value); break;
                    default: null
                }
            }
        }
        );
    };

    function main(event: Event): void {
        const detail: detail = (event as CustomEvent).detail;
        for (const [query_input, changes] of Object.entries(detail)) {
            const query = QUERY[query_input] || query_input
            const elements = document.querySelectorAll(query);

            elements.forEach(el => {
                changes === "i" ? resetElement(el as HTMLElement) : applyToElement(el as HTMLElement, changes)
            })
        }
    }

    main(event);
});
