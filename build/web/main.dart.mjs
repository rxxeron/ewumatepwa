// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: x0 => new Int16Array(x0),
      AC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      AD: x0 => x0.screen,
      AE: x0 => new ResizeObserver(x0),
      AF: x0 => x0.key,
      AG: () => new WeakMap(),
      AH: (d, digits) => d.toFixed(digits),
      AI: (x0,x1) => x0.vibrate(x1),
      AJ: x0 => x0.src,
      AK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      AL: (x0,x1) => { x0.disabled = x1 },
      AM: x0 => new DOMException(x0),
      AN: (x0,x1,x2) => x0.sqlite3_extended_result_codes(x1,x2),
      AO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      AP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      AQ: (x0,x1,x2) => x0.setPersonProperties(x1,x2),
      AR: (x0,x1) => x0.item(x1),
      AS: (x0,x1,x2) => x0.createPolicy(x1,x2),
      AT: (x0,x1) => x0.removeChild(x1),
      B: s => printToConsole(s),
      BB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      BC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      BD: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      BE: (x0,x1) => x0.getPropertyValue(x1),
      BF: x0 => x0.identifier,
      BG: x0 => x0.debugSkipFontRetryDelay,
      BH: x0 => x0.maxHeight,
      BI: x0 => x0.content,
      BJ: (x0,x1) => x0.get(x1),
      BK: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      BL: (x0,x1) => x0.getItem(x1),
      BM: x0 => x0.error,
      BN: (x0,x1,x2,x3,x4) => x0.sqlite3_open_v2(x1,x2,x3,x4),
      BO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      BP: (x0,x1) => { x0.onupgradeneeded = x1 },
      BQ: (x0,x1,x2,x3) => x0.capture(x1,x2,x3),
      BR: x0 => x0.length,
      BS: (x0,x1) => x0.createScriptURL(x1),
      BT: x0 => x0.firstChild,
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: x0 => new Uint16Array(x0),
      CC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      CD: x0 => x0.tabIndex,
      CE: x0 => globalThis.parseFloat(x0),
      CF: x0 => x0.touches,
      CG: x0 => x0.status,
      CH: x0 => x0.maxWidth,
      CI: x0 => x0.document,
      CJ: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      CK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CL: x0 => x0.localStorage,
      CM: (x0,x1) => { x0.onabort = x1 },
      CN: x0 => x0.sqlite3_initialize(),
      CO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      CP: x0 => ({autoIncrement: x0}),
      CQ: (x0,x1) => x0.captureLog(x1),
      CR: x0 => x0.getRootNode(),
      CS: (x0,x1) => x0.appendChild(x1),
      CT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: x0 => new Int32Array(x0),
      DC: (x0,x1) => x0.querySelector(x1),
      DD: (x0,x1) => x0.contains(x1),
      DE: (x0,x1) => x0.getComputedStyle(x1),
      DF: x0 => x0.pressure,
      DG: x0 => new Uint8Array(x0),
      DH: x0 => x0.minHeight,
      DI: x0 => new WeakRef(x0),
      DJ: x0 => x0.naturalHeight,
      DK: (o, t) => typeof o === t,
      DL: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      DM: (x0,x1) => { x0.oncomplete = x1 },
      DN: (x0,x1,x2,x3) => x0.dart_sqlite3_register_vfs(x1,x2,x3),
      DO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      DP: (x0,x1,x2) => x0.createObjectStore(x1,x2),
      DQ: (x0,x1) => x0.alias(x1),
      DR: (x0,x1) => x0.closest(x1),
      DS: x0 => x0.head,
      DT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      EC: (x0,x1) => x0.item(x1),
      ED: x0 => x0.activeElement,
      EE: x0 => x0.documentElement,
      EF: x0 => x0.tiltY,
      EG: (x0,x1,x2) => x0.set(x1,x2),
      EH: x0 => x0.minWidth,
      EI: x0 => x0.deref(),
      EJ: x0 => x0.naturalWidth,
      EK: x0 => x0.data,
      EL: x0 => x0.history,
      EM: (x0,x1) => x0.objectStore(x1),
      EN: (x0,x1) => globalThis.Atomics.load(x0,x1),
      EO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      EP: x0 => ({unique: x0}),
      EQ: x0 => x0.get_distinct_id(),
      ER: x0 => x0.host,
      ES: (x0,x1) => { x0.nonce = x1 },
      ET: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      F: () => new Error().stack,
      FB: x0 => new Uint32Array(x0),
      FC: x0 => x0.length,
      FD: x0 => x0.parentNode,
      FE: x0 => x0.computedStyleMap(),
      FF: x0 => x0.tiltX,
      FG: x0 => x0.buffer,
      FH: (x0,x1) => x0.removeProperty(x1),
      FI: () => globalThis.WeakRef,
      FJ: (x0,x1) => { x0.src = x1 },
      FK: (x0,x1,x2) => x0.close(x1,x2),
      FL: x0 => x0.href,
      FM: (x0,x1) => x0.sqlite3_get_autocommit(x1),
      FN: (x0,x1,x2) => globalThis.Atomics.wait(x0,x1,x2),
      FO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      FP: (x0,x1,x2,x3) => x0.createIndex(x1,x2,x3),
      FQ: x0 => x0.reset(),
      FR: (o) => {
        const typeofValue = typeof o;
        return (typeofValue === 'object') ||
            typeofValue === 'function';
      },
      FS: x0 => x0.nonce,
      FT: x0 => x0.parentNode,
      G: s => JSON.stringify(s),
      GB: x0 => new Float32Array(x0),
      GC: (x0,x1) => x0.querySelectorAll(x1),
      GD: x0 => x0.tagName,
      GE: (x0,x1) => x0.get(x1),
      GF: x0 => x0.pointerType,
      GG: x0 => x0.wasmMemory,
      GH: (x0,x1) => x0.add(x1),
      GI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      GJ: x0 => x0.decode(),
      GK: (x0,x1) => x0.close(x1),
      GL: (x0,x1) => x0.removeItem(x1),
      GM: (x0,x1) => x0.sqlite3_finalize(x1),
      GN: (x0,x1,x2) => globalThis.Atomics.notify(x0,x1,x2),
      GO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      GP: (x0,x1) => x0.createObjectStore(x1),
      GQ: (x0,x1) => x0.debug(x1),
      GR: (x0,x1) => x0.get_property(x1),
      GS: (x0,x1) => { x0.src = x1 },
      GT: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      HC: (x0,x1) => x0.getAttribute(x1),
      HD: x0 => x0.target,
      HE: (o, p) => p in o,
      HF: x0 => x0.pointerId,
      HG: () => globalThis.window._flutter_skwasmInstance,
      HH: x0 => x0.data,
      HI: (a, s, e) => a.slice(s, e),
      HJ: (x0,x1) => { x0.decoding = x1 },
      HK: x0 => x0.close(),
      HL: (x0,x1,x2) => x0.setItem(x1,x2),
      HM: (x0,x1) => x0.sqlite3_reset(x1),
      HN: (x0,x1,x2) => globalThis.Atomics.store(x0,x1,x2),
      HO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      HP: x0 => x0.oldVersion,
      HQ: (x0,x1,x2) => x0.isFeatureEnabled(x1,x2),
      HR: x0 => x0.permissions,
      HS: (x0,x1) => { x0.src = x1 },
      HT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Float64Array(x0),
      IC: x0 => x0.remove(),
      ID: x0 => x0.clientY,
      IE: (x0,x1) => { x0.textContent = x1 },
      IF: x0 => x0.getCoalescedEvents(),
      IG: x0 => x0.arrayBuffer(),
      IH: (x0,x1) => { x0.scrollTop = x1 },
      II: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      IJ: (x0,x1) => { x0.crossOrigin = x1 },
      IK: (x0,x1) => x0.send(x1),
      IL: x0 => new BroadcastChannel(x0),
      IM: x0 => x0.buffer,
      IN: (x0,x1,x2) => x0.setInt32(x1,x2),
      IO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      IP: () => globalThis.indexedDB,
      IQ: (x0,x1,x2,x3) => x0.group(x1,x2,x3),
      IR: x0 => x0.geolocation,
      IS: (x0,x1) => { x0.defer = x1 },
      IT: (x0,x1) => { x0.display = x1 },
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (x0,x1) => x0.appendChild(x1),
      JD: x0 => x0.clientX,
      JE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JF: (x0,x1) => x0.getModifierState(x1),
      JG: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      JH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      JI: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      JJ: (x0,x1) => x0.revokeObjectURL(x1),
      JK: x0 => x0.readyState,
      JL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JM: (x0,x1) => x0.sqlite3_errstr(x1),
      JN: (x0,x1,x2) => x0.setBigInt64(x1,x2),
      JO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      JP: (x0,x1) => ({name: x0,length: x1}),
      JQ: (x0,x1,x2) => x0.setPersonPropertiesForFlags(x1,x2),
      JR: x0 => x0.mediaDevices,
      JS: (x0,x1) => { x0.async = x1 },
      JT: x0 => x0.style,
      K: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      KB: x0 => new ArrayBuffer(x0),
      KC: (x0,x1) => x0.append(x1),
      KD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      KE: x0 => x0.matches,
      KF: s => s.trimLeft(),
      KG: (x0,x1) => x0.fetch(x1),
      KH: (x0,x1) => { x0.value = x1 },
      KI: () => new AbortController(),
      KJ: (x0,x1) => x0.createObjectURL(x1),
      KK: (x0,x1) => { x0.binaryType = x1 },
      KL: x0 => x0.close(),
      KM: (x0,x1) => x0.sqlite3_errmsg(x1),
      KN: x0 => new Worker(x0),
      KO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      KP: (x0,x1) => x0.update(x1),
      KQ: x0 => x0.resetPersonPropertiesForFlags(),
      KR: x0 => x0.baseURI,
      KS: x0 => x0.trustedTypes,
      KT: (x0,x1) => { x0.draggable = x1 },
      L: o => o === undefined,
      LB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      LC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      LD: x0 => x0.getBoundingClientRect(),
      LE: (x0,x1) => x0.matchMedia(x1),
      LF: (x0,x1) => x0[x1],
      LG: x0 => x0.fontFallbackBaseUrl,
      LH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      LI: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      LJ: x0 => x0.URL,
      LK: (a, l) => a.length = l,
      LL: (x0,x1) => x0.postMessage(x1),
      LM: (x0,x1) => x0.sqlite3_error_offset(x1),
      LN: (x0,x1,x2) => new DataView(x0,x1,x2),
      LO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      LP: x0 => x0.name,
      LQ: (x0,x1,x2) => x0.setGroupPropertiesForFlags(x1,x2),
      LR: x0 => x0.document,
      LS: x0 => x0.trustedTypes,
      LT: x0 => x0.onLine,
      M: o => String(o),
      MB: (x0,x1,x2) => new DataView(x0,x1,x2),
      MC: x0 => x0.style,
      MD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      ME: x0 => x0.matches,
      MF: x0 => x0.index,
      MG: (x0,x1,x2) => x0.slice(x1,x2),
      MH: (x0,x1) => { x0.value = x1 },
      MI: (x0,x1) => globalThis.fetch(x0,x1),
      MJ: x0 => new Blob(x0),
      MK: x0 => new Blob(x0),
      ML: (x0,x1) => { x0.onmessage = x1 },
      MM: (x0,x1) => x0.sqlite3_extended_errcode(x1),
      MN: () => globalThis.Uint8Array,
      MO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      MP: x0 => globalThis.IDBKeyRange.only(x0),
      MQ: (x0,x1) => x0.resetGroupPropertiesForFlags(x1),
      MR: (x0,x1) => x0.querySelector(x1),
      MS: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      MT: x0 => x0.length,
      N: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      NB: (o, p) => o[p],
      NC: x0 => x0.debugShowSemanticsNodes,
      ND: s => new Date(s * 1000).getTimezoneOffset() * 60,
      NE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      NF: s => s.toUpperCase(),
      NG: (x0,x1) => x0.decode(x1),
      NH: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      NI: (x0,x1) => x0.get(x1),
      NJ: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      NK: () => new FileReader(),
      NL: x0 => x0.input,
      NM: (x0,x1) => x0.sqlite3_step(x1),
      NN: x0 => x0.communicationBuffer,
      NO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      NP: (x0,x1,x2) => x0.put(x1,x2),
      NQ: x0 => x0.opt_in_capturing(),
      NR: (x0,x1) => x0.append(x1),
      NS: x0 => { globalThis.onGoogleLibraryLoad = x0 },
      NT: x0 => x0.getReader(),
      O: (x0,x1) => x0.didCreateEngineInitializer(x1),
      OB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      OC: o => o,
      OD: Date.now,
      OE: f => f.dartFunction,
      OF: x0 => x0.pop(),
      OG: (x0,x1) => x0.adoptText(x1),
      OH: x0 => x0.value,
      OI: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      OJ: x0 => new window.ImageDecoder(x0),
      OK: (x0,x1) => x0.readAsArrayBuffer(x1),
      OL: () => new MessageChannel(),
      OM: (x0,x1,x2,x3,x4) => x0.dart_sqlite3_bind_blob(x1,x2,x3,x4),
      ON: () => globalThis.Int32Array,
      OO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      OP: (x0,x1) => x0.getKey(x1),
      OQ: x0 => x0.opt_out_capturing(),
      OR: x0 => x0.body,
      OS: () => globalThis.Notification.permission,
      OT: x0 => x0.value,
      P: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      PC: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      PD: (handle) => clearTimeout(handle),
      PE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PF: x0 => x0.flags,
      PG: x0 => x0.first(),
      PH: x0 => x0.selectionDirection,
      PI: (x0,x1) => x0.forEach(x1),
      PJ: x0 => x0.name,
      PK: x0 => x0.result,
      PL: x0 => globalThis.Array.isArray(x0),
      PM: (x0,x1) => x0.dart_sqlite3_malloc(x1),
      PN: x0 => x0.byteLength,
      PO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PP: (x0,x1) => x0.delete(x1),
      PQ: x0 => x0.has_opted_out_capturing(),
      PR: (x0,x1) => { x0.id = x1 },
      PS: x0 => x0.message,
      PT: x0 => x0.done,
      Q: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      QB: o => o.byteOffset,
      QC: (x0,x1) => x0.warn(x1),
      QD: (x0,x1) => x0.closest(x1),
      QE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      QF: (a, s) => a.join(s),
      QG: x0 => x0.next(),
      QH: x0 => x0.selectionStart,
      QI: x0 => x0.name,
      QJ: x0 => x0.repetitionCount,
      QK: () => new XMLHttpRequest(),
      QL: x0 => x0.table,
      QM: (x0,x1,x2,x3,x4) => x0.dart_sqlite3_bind_text(x1,x2,x3,x4),
      QN: x0 => x0.synchronizationBuffer,
      QO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      QP: (x0,x1) => x0.put(x1),
      QQ: (x0,x1,x2) => x0.getFeatureFlag(x1,x2),
      QR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      QS: x0 => x0.code,
      QT: x0 => x0.read(),
      R: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      RB: o => o.buffer,
      RC: x0 => x0.console,
      RD: x0 => x0.bottom,
      RE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      RF: (x0,x1) => x0.error(x1),
      RG: x0 => x0.current(),
      RH: x0 => x0.selectionEnd,
      RI: x0 => x0.statusText,
      RJ: x0 => x0.frameCount,
      RK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      RL: x0 => x0.kind,
      RM: (x0,x1,x2,x3) => x0.sqlite3_bind_double(x1,x2,x3),
      RN: (x0,x1,x2) => x0.postMessage(x1,x2),
      RO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      RP: (x0,x1,x2) => x0.postMessage(x1,x2),
      RQ: x0 => x0.getAllFeatureFlags(),
      RR: (x0,x1,x2,x3) => x0.toBlob(x1,x2,x3),
      RS: () => globalThis.Notification.requestPermission(),
      RT: (x0,x1) => new OffscreenCanvas(x0,x1),
      S: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      SB: Function.prototype.call.bind(DataView.prototype.getUint8),
      SC: () => globalThis.window,
      SD: x0 => x0.top,
      SE: (o, i) => o[i],
      SF: () => globalThis.console,
      SG: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      SH: x0 => x0.value,
      SI: x0 => x0.url,
      SJ: x0 => x0.selectedTrack,
      SK: x0 => x0.send(),
      SL: (x0,x1) => ({kind: x0,table: x1}),
      SM: (x0,x1,x2,x3) => x0.sqlite3_bind_int64(x1,x2,x3),
      SN: x0 => new SharedArrayBuffer(x0),
      SO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      SP: x0 => x0.randomUUID(),
      SQ: (x0,x1) => x0.register(x1),
      SR: x0 => x0.size,
      SS: (x0,x1) => ({vapidKey: x0,serviceWorkerRegistration: x1}),
      ST: x0 => x0.assetBase,
      T: x0 => new Promise(x0),
      TB: (b, o) => new DataView(b, o),
      TC: (o, c) => o instanceof c,
      TD: x0 => x0.right,
      TE: o => o.length,
      TF: s => s.trimRight(),
      TG: x0 => x0.v8BreakIterator,
      TH: x0 => x0.selectionDirection,
      TI: x0 => x0.status,
      TJ: x0 => x0.completed,
      TK: x0 => x0.type,
      TL: () => ({}),
      TM: x0 => globalThis.BigInt(x0),
      TN: (x0,x1,x2,x3) => ({clientVersion: x0,root: x1,synchronizationBuffer: x2,communicationBuffer: x3}),
      TO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      TP: () => globalThis.crypto,
      TQ: (x0,x1) => x0.unregister(x1),
      TR: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      TS: (x0,x1) => globalThis.firebase_messaging.getToken(x0,x1),
      TT: x0 => x0.loader,
      U: (x0,x1,x2) => x0.call(x1,x2),
      UB: (b, o, l) => new DataView(b, o, l),
      UC: (x0,x1) => x0.exec(x1),
      UD: x0 => x0.left,
      UE: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      UF: x0 => x0.blur(),
      UG: () => globalThis.Intl,
      UH: x0 => x0.selectionStart,
      UI: x0 => x0.getReader(),
      UJ: x0 => x0.ready,
      UK: x0 => x0.response,
      UL: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      UM: (x0,x1,x2) => x0.sqlite3_bind_null(x1,x2),
      UN: x0 => x0.close(),
      UO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3,x4) { return wasmFunction(f,arguments.length,x0,x1,x2,x3,x4) }),
      UP: x0 => x0.port2,
      UQ: x0 => x0.get_session_id(),
      UR: (x0,x1,x2,x3,x4,x5) => x0.drawImage(x1,x2,x3,x4,x5),
      US: x0 => x0.link,
      UT: () => globalThis._flutter,
      V: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      VB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      VC: x0 => x0.length,
      VD: x0 => x0.clientY,
      VE: x0 => x0.language,
      VF: x0 => x0.button,
      VG: (x0,x1) => x0.segment(x1),
      VH: x0 => x0.selectionEnd,
      VI: x0 => x0.read(),
      VJ: x0 => x0.tracks,
      VK: (x0,x1) => { x0.responseType = x1 },
      VL: (x0,x1,x2,x3) => x0.request(x1,x2,x3),
      VM: (x0,x1) => x0.sqlite3_bind_parameter_count(x1),
      VN: x0 => x0.getSize(),
      VO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      VP: x0 => x0.terminate(),
      VQ: (x0,x1,x2) => x0.addExceptionStep(x1,x2),
      VR: x0 => x0.height,
      VS: x0 => x0.analyticsLabel,
      W: x0 => new Array(x0),
      WB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      WC: (x0,x1) => { x0.lastIndex = x1 },
      WD: x0 => x0.clientX,
      WE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      WF: x0 => x0.innerHeight,
      WG: x0 => x0.index,
      WH: x0 => x0.keyCode,
      WI: x0 => x0.value,
      WJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      WK: x0 => x0.vendor,
      WL: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      WM: (x0,x1) => x0.sqlite3_stmt_isexplain(x1),
      WN: (x0,x1) => x0.truncate(x1),
      WO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      WP: (x0,x1) => new SharedWorker(x0,x1),
      WQ: x0 => x0.sessionRecordingStarted(),
      WR: x0 => x0.width,
      WS: x0 => x0.image,
      X: o => [o],
      XB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      XC: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      XD: x0 => x0.changedTouches,
      XE: () => globalThis.window.FinalizationRegistry,
      XF: x0 => x0.innerWidth,
      XG: x0 => x0.next(),
      XH: (x0,x1) => x0.scrollIntoView(x1),
      XI: x0 => x0.done,
      XJ: (x0,x1) => x0.decode(x1),
      XK: x0 => x0.navigator,
      XL: (o, p, v) => o[p] = v,
      XM: (x0,x1) => x0.dart_sqlite3_free(x1),
      XN: x0 => ({at: x0}),
      XO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      XP: x0 => x0.start(),
      XQ: x0 => x0.resetSessionId(),
      XR: (x0,x1) => x0.getContext(x1),
      XS: x0 => x0.body,
      Y: (o0, o1) => [o0, o1],
      YB: (t, s) => t.set(s),
      YC: o => o instanceof RegExp,
      YD: x0 => x0.offsetY,
      YE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      YF: x0 => x0.height,
      YG: x0 => x0.value,
      YH: x0 => x0.multiViewEnabled,
      YI: x0 => x0.cancel(),
      YJ: x0 => x0.displayHeight,
      YK: x0 => globalThis.fetch(x0),
      YL: (o,s,v) => o[s] = v,
      YM: (x0,x1,x2,x3,x4,x5,x6) => x0.sqlite3_prepare_v3(x1,x2,x3,x4,x5,x6),
      YN: x0 => x0.flush(),
      YO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      YP: x0 => x0.port,
      YQ: x0 => x0.startSessionRecording(),
      YR: (x0,x1) => { x0.height = x1 },
      YS: x0 => x0.title,
      Z: (o0, o1, o2) => [o0, o1, o2],
      ZB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      ZC: (string, times) => string.repeat(times),
      ZD: x0 => x0.offsetX,
      ZE: x0 => new window.FinalizationRegistry(x0),
      ZF: x0 => x0.width,
      ZG: x0 => x0.done,
      ZH: (x0,x1) => x0.replaceWith(x1),
      ZI: x0 => x0.body,
      ZJ: x0 => x0.displayWidth,
      ZK: x0 => x0.arrayBuffer(),
      ZL: () => Symbol("jsBoxedDartObjectProperty"),
      ZM: (x0,x1,x2,x3,x4,x5) => x0.sqlite3_exec(x1,x2,x3,x4,x5),
      ZN: (x0,x1) => x0.write(x1),
      ZO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      ZP: (x0,x1) => x0.transferFromImageBitmap(x1),
      ZQ: x0 => x0.stopSessionRecording(),
      ZR: (x0,x1) => { x0.width = x1 },
      ZS: x0 => x0.fcmOptions,
      a: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      aB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      aC: x0 => x0.dotAll,
      aD: x0 => x0.type,
      aE: (x0,x1) => x0.unregister(x1),
      aF: x0 => x0.clientHeight,
      aG: (o, m, a) => o[m].apply(o, a),
      aH: (x0,x1) => { x0.type = x1 },
      aI: x0 => x0.headers,
      aJ: x0 => x0.duration,
      aK: x0 => ({type: x0}),
      aL: (x0,x1) => x0.call(x1),
      aM: (x0,x1) => x0.sqlite3_close_v2(x1),
      aN: (x0,x1,x2) => x0.write(x1,x2),
      aO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      aP: (x0,x1) => x0.getContext(x1),
      aQ: (x0,x1,x2) => x0.captureException(x1,x2),
      aR: x0 => x0.height,
      aS: x0 => x0.notification,
      b: (x0,x1,x2) => { x0[x1] = x2 },
      bB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      bC: x0 => x0.unicode,
      bD: x0 => x0.maxTouchPoints,
      bE: (x0,x1) => x0.contains(x1),
      bF: x0 => x0.clientWidth,
      bG: x0 => x0.iterator,
      bH: (x0,x1) => { x0.className = x1 },
      bI: x0 => x0.signal,
      bJ: x0 => x0.image,
      bK: (x0,x1) => new Blob(x0,x1),
      bL: x0 => x0.locks,
      bM: (x0,x1) => x0.sqlite3_last_insert_rowid(x1),
      bN: x0 => x0.createSyncAccessHandle(),
      bO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3,x4) { return wasmFunction(f,arguments.length,x0,x1,x2,x3,x4) }),
      bP: (x0,x1) => { x0.height = x1 },
      bQ: x0 => x0.sessionManager,
      bR: x0 => x0.width,
      bS: x0 => x0.messageId,
      c: o => o,
      cB: Function.prototype.call.bind(DataView.prototype.getUint32),
      cC: x0 => x0.ignoreCase,
      cD: x0 => x0.platform,
      cE: (s) => +s,
      cF: (x0,x1) => { x0.content = x1 },
      cG: () => globalThis.Symbol,
      cH: (x0,x1) => { x0.tabIndex = x1 },
      cI: x0 => x0.abort(),
      cJ: x0 => x0.close(),
      cK: x0 => globalThis.URL.createObjectURL(x0),
      cL: () => globalThis.navigator,
      cM: x0 => globalThis.Number(x0),
      cN: x0 => ({create: x0}),
      cO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      cP: (x0,x1) => { x0.width = x1 },
      cQ: (x0,x1,x2) => x0.getFeatureFlagResult(x1,x2),
      cR: x0 => x0.remove(),
      cS: x0 => x0.from,
      d: (o, p) => o[p],
      dB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      dC: x0 => x0.multiline,
      dD: x0 => x0.body,
      dE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      dF: (x0,x1) => { x0.name = x1 },
      dG: (x0,x1) => new Intl.Segmenter(x0,x1),
      dH: (x0,x1) => { x0.name = x1 },
      dI: (x0,x1) => x0.getRandomValues(x1),
      dJ: x0 => x0.body,
      dK: x0 => x0.click(),
      dL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      dM: (x0,x1) => x0.sqlite3_changes(x1),
      dN: (x0,x1,x2) => x0.getFileHandle(x1,x2),
      dO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      dP: x0 => x0.height,
      dQ: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      dR: (x0,x1) => { x0.src = x1 },
      dS: x0 => x0.collapseKey,
      e: () => globalThis,
      eB: Function.prototype.call.bind(DataView.prototype.getInt32),
      eC: (string, token) => string.split(token),
      eD: () => globalThis.document,
      eE: s => s.trim(),
      eF: x0 => x0.head,
      eG: x0 => x0.Segmenter,
      eH: (x0,x1) => { x0.placeholder = x1 },
      eI: () => globalThis.crypto,
      eJ: () => globalThis.window.ImageDecoder,
      eK: x0 => globalThis.URL.revokeObjectURL(x0),
      eL: (x0,x1) => x0.postMessage(x1),
      eM: (x0,x1,x2) => x0.sqlite3_column_name(x1,x2),
      eN: x0 => ({create: x0}),
      eO: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      eP: x0 => x0.width,
      eQ: (x0,x1) => x0.onFeatureFlags(x1),
      eR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eS: x0 => x0.data,
      f: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      fC: o => o instanceof Array,
      fD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      fE: x0 => x0.classList,
      fF: (x0,x1) => x0.removeChild(x1),
      fG: () => new TextDecoder(),
      fH: (x0,x1) => { x0.autocomplete = x1 },
      fI: l => new DataView(new ArrayBuffer(l)),
      fJ: x0 => x0.headers,
      fK: (x0,x1) => { x0.download = x1 },
      fL: x0 => x0.close(),
      fM: (x0,x1,x2) => x0.sqlite3_column_blob(x1,x2),
      fN: (x0,x1,x2) => x0.getDirectoryHandle(x1,x2),
      fO: (x0,x1) => x0.getBigInt64(x1),
      fP: x0 => x0.rasterEndMilliseconds,
      fQ: x0 => x0.reloadFeatureFlags(),
      fR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      g: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gB: o => o instanceof Uint16Array,
      gC: (a, i) => a[i],
      gD: x0 => x0.hasFocus(),
      gE: x0 => x0.preventDefault(),
      gF: x0 => x0.firstChild,
      gG: (handle) => clearInterval(handle),
      gH: (x0,x1) => { x0.name = x1 },
      gI: (o, p) => p in o,
      gJ: x0 => x0.decode(),
      gK: (x0,x1) => { x0.target = x1 },
      gL: (x0,x1) => ({i: x0,p: x1}),
      gM: (x0,x1,x2) => x0.sqlite3_column_bytes(x1,x2),
      gN: (x0,x1) => new URL(x0,x1),
      gO: (x0,x1) => x0.getInt32(x1),
      gP: x0 => x0.rasterStartMilliseconds,
      gQ: x0 => x0.config,
      gR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      h: (x0,x1) => ({addView: x0,removeView: x1}),
      hB: Function.prototype.call.bind(DataView.prototype.getUint16),
      hC: a => a.length,
      hD: x0 => x0.relatedTarget,
      hE: x0 => x0.parent,
      hF: x0 => x0.viewConstraints,
      hG: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      hH: (x0,x1) => { x0.placeholder = x1 },
      hI: x0 => x0.groups,
      hJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      hK: (x0,x1) => { x0.href = x1 },
      hL: (x0,x1) => ({c: x0,r: x1}),
      hM: (x0,x1,x2) => x0.sqlite3_column_text(x1,x2),
      hN: x0 => x0.pathname,
      hO: (x0,x1) => x0.read(x1),
      hP: x0 => x0.imageBitmaps,
      hQ: x0 => x0.getFlagVariants(),
      hR: (x0,x1) => { x0.onerror = x1 },
      hS: (x0,x1) => ({next: x0,error: x1}),
      i: (l, r) => l === r,
      iB: o => o instanceof Int16Array,
      iC: (x0,x1) => x0.test(x1),
      iD: x0 => x0.shiftKey,
      iE: x0 => x0.timeStamp,
      iF: x0 => x0.hostElement,
      iG: () => Date.now(),
      iH: (x0,x1) => { x0.action = x1 },
      iI: () => globalThis.window.setRxxeronBypassed(),
      iJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iK: (x0,x1) => x0.createElement(x1),
      iL: (x0,x1) => { x0.onmessage = x1 },
      iM: (x0,x1,x2) => x0.sqlite3_column_double(x1,x2),
      iN: x0 => x0.getDirectory(),
      iO: (x0,x1,x2) => x0.read(x1,x2),
      iP: x0 => x0.canvasKitMaximumSurfaces,
      iQ: x0 => x0.featureFlags,
      iR: (x0,x1) => { x0.oncancel = x1 },
      iS: (x0,x1) => globalThis.firebase_messaging.onMessage(x0,x1),
      j: x0 => x0.random(),
      jB: Function.prototype.call.bind(DataView.prototype.getInt16),
      jC: x0 => x0.userAgent,
      jD: (decoder, codeUnits) => decoder.decode(codeUnits),
      jE: (x0,x1) => x0.hasAttribute(x1),
      jF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      jH: (x0,x1) => { x0.method = x1 },
      jI: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      jJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      jK: () => globalThis.document,
      jL: (o, a) => o == a,
      jM: (x0,x1,x2) => x0.sqlite3_column_int64(x1,x2),
      jN: x0 => x0.storage,
      jO: () => globalThis.WebAssembly,
      jP: x0 => x0.nextSibling,
      jQ: x0 => x0.pathname,
      jR: (x0,x1) => { x0.onchange = x1 },
      jS: x0 => globalThis.firebase_messaging.getMessaging(x0),
      k: o => o,
      kB: o => o instanceof Uint8ClampedArray,
      kC: x0 => x0.navigator,
      kD: () => new TextDecoder("utf-8", {fatal: true}),
      kE: x0 => x0.buttons,
      kF: x0 => ({runApp: x0}),
      kG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      kH: (x0,x1) => { x0.noValidate = x1 },
      kI: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      kJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      kK: () => globalThis.window.triggerPWAInstall(),
      kL: x0 => x0.r,
      kM: (x0,x1,x2) => x0.sqlite3_column_type(x1,x2),
      kN: () => globalThis.navigator,
      kO: x0 => x0.href,
      kP: (x0,x1) => x0.debug(x1),
      kQ: x0 => x0.host,
      kR: x0 => x0.type,
      kS: x0 => globalThis.firebase_core.getApp(x0),
      l: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      lB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      lC: Function.prototype.call.bind(String.prototype.toLowerCase),
      lD: () => new TextDecoder("utf-8", {fatal: false}),
      lE: x0 => x0.ctrlKey,
      lF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      lG: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      lH: (x0,x1) => x0.removeAttribute(x1),
      lI: () => globalThis.window.isRxxeronBypassed(),
      lJ: x0 => x0.send(),
      lK: Function.prototype.call.bind(DataView.prototype.getBigUint64),
      lL: x0 => x0.c,
      lM: (x0,x1) => x0.sqlite3_column_count(x1),
      lN: (x0,x1) => globalThis.fetch(x0,x1),
      lO: (x0,x1) => x0.openCursor(x1),
      lP: x0 => x0.hostElement,
      lQ: () => globalThis.window.posthog,
      lR: x0 => x0.lastModified,
      lS: (x0,x1,x2) => globalThis.firebase_core.registerVersion(x0,x1,x2),
      m: () => globalThis.Math,
      mB: Function.prototype.call.bind(DataView.prototype.setInt32),
      mC: Object.is,
      mD: (a, i, v) => a[i] = v,
      mE: x0 => x0.y,
      mF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      mG: x0 => x0.history,
      mH: x0 => x0.isConnected,
      mI: () => globalThis.window.isIOSDevice(),
      mJ: x0 => x0.status,
      mK: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      mL: x0 => x0.p,
      mM: (x0,x1,x2,x3,x4,x5,x6) => x0.dart_sqlite3_create_function_v2(x1,x2,x3,x4,x5,x6),
      mN: (x0,x1) => x0.sqlite3session_delete(x1),
      mO: x0 => x0.arrayBuffer(),
      mP: x0 => x0.location,
      mQ: (x0,x1,x2) => x0._overrideSDKInfo(x1,x2),
      mR: x0 => x0.name,
      mS: x0 => x0.sessionStorage,
      n: (x0,x1) => x0.prepend(x1),
      nB: Function.prototype.call.bind(DataView.prototype.setUint32),
      nC: x0 => x0.vendor,
      nD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      nE: x0 => x0.x,
      nF: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      nG: x0 => x0.search,
      nH: x0 => x0.click(),
      nI: () => globalThis.window.isPWAStandalone(),
      nJ: x0 => x0.response,
      nK: x0 => { globalThis.window.onServiceWorkerUpdateCallback = x0 },
      nL: x0 => x0.i,
      nM: (x0,x1,x2,x3) => x0.sqlite3_result_error(x1,x2,x3),
      nN: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      nO: () => globalThis.Blob,
      nP: (x0,x1) => x0.getModifierState(x1),
      nQ: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      nR: (x0,x1) => x0.item(x1),
      nS: x0 => x0.measurementId,
      o: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      oB: Function.prototype.call.bind(DataView.prototype.setInt16),
      oC: (x0,x1) => x0.createTextNode(x1),
      oD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      oE: x0 => x0.scrollTop,
      oF: o => o.byteLength,
      oG: x0 => x0.location,
      oH: (x0,x1) => x0.getElementsByClassName(x1),
      oI: () => globalThis.window.isPWAInstallable(),
      oJ: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      oK: () => globalThis.window.location.reload(),
      oL: x0 => x0.port1,
      oM: (x0,x1,x2) => x0.sqlite3_result_subtype(x1,x2),
      oN: (x0,x1) => x0.unregister(x1),
      oO: x0 => x0.value,
      oP: x0 => x0.metaKey,
      oQ: (x0,x1) => globalThis.Object.assign(x0,x1),
      oR: x0 => x0.length,
      oS: x0 => x0.appId,
      p: b => !!b,
      pB: Function.prototype.call.bind(DataView.prototype.setUint16),
      pC: (x0,x1) => { x0.id = x1 },
      pD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      pE: x0 => x0.offsetTop,
      pF: () => typeof dartUseDateNowForTicks !== "undefined",
      pG: x0 => x0.pathname,
      pH: (x0,x1) => x0.dispatchEvent(x1),
      pI: x0 => { globalThis.window.onAppInstalledCallback = x0 },
      pJ: (x0,x1) => { x0.responseType = x1 },
      pK: (x0,x1,x2) => x0.insertBefore(x1,x2),
      pL: (x0,x1,x2) => x0.transaction(x1,x2),
      pM: (x0,x1,x2,x3,x4) => x0.sqlite3_result_blob64(x1,x2,x3,x4),
      pN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      pO: x0 => x0.key,
      pP: x0 => x0.altKey,
      pQ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      pR: x0 => x0.files,
      pS: x0 => x0.messagingSenderId,
      q: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qB: Function.prototype.call.bind(DataView.prototype.setUint8),
      qC: (x0,x1) => { x0.nonce = x1 },
      qD: x0 => x0.visibilityState,
      qE: x0 => x0.scrollLeft,
      qF: () => Date.now(),
      qG: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      qH: (x0,x1) => x0.createEvent(x1),
      qI: x0 => { globalThis.window.onAppInstallableCallback = x0 },
      qJ: () => new XMLHttpRequest(),
      qK: x0 => x0.id,
      qL: x0 => x0.close(),
      qM: (x0,x1,x2,x3,x4) => x0.sqlite3_result_text(x1,x2,x3,x4),
      qN: x0 => new FinalizationRegistry(x0),
      qO: x0 => x0.continue(),
      qP: x0 => x0.ctrlKey,
      qQ: (x0,x1) => x0.set_config(x1),
      qR: x0 => x0.target,
      qS: x0 => x0.storageBucket,
      r: (x0,x1) => x0.focus(x1),
      rB: Function.prototype.call.bind(DataView.prototype.setInt8),
      rC: x0 => x0.nonce,
      rD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      rE: x0 => x0.offsetLeft,
      rF: () => 1000 * performance.now(),
      rG: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      rH: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      rI: x0 => x0.naturalHeight,
      rJ: x0 => x0.origin,
      rK: x0 => x0.offsetHeight,
      rL: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      rM: (x0,x1,x2) => x0.sqlite3_result_double(x1,x2),
      rN: () => globalThis.FinalizationRegistry,
      rO: x0 => x0.error,
      rP: x0 => x0.isComposing,
      rQ: x0 => x0.getBoundingClientRect(),
      rR: (x0,x1) => x0.replaceChildren(x1),
      rS: x0 => x0.databaseURL,
      s: () => ({}),
      sB: Function.prototype.call.bind(DataView.prototype.getInt8),
      sC: () => globalThis.window.flutterConfiguration,
      sD: x0 => x0.disconnect(),
      sE: x0 => x0.offsetParent,
      sF: (x0,x1) => x0.requestAnimationFrame(x1),
      sG: o => Object.keys(o),
      sH: x0 => x0.readText(),
      sI: x0 => x0.naturalWidth,
      sJ: x0 => x0.location,
      sK: x0 => x0.offsetWidth,
      sL: () => globalThis.Promise.resolve(),
      sM: (x0,x1,x2) => x0.sqlite3_result_int64(x1,x2),
      sN: x0 => x0.exports,
      sO: x0 => x0.result,
      sP: x0 => x0.code,
      sQ: (x0,x1,x2,x3) => ({x: x0,y: x1,width: x2,height: x3}),
      sR: (x0,x1,x2) => x0.setAttribute(x1,x2),
      sS: x0 => x0.authDomain,
      t: (o, p, v) => o[p] = v,
      tB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      tC: (x0,x1) => x0.attachShadow(x1),
      tD: x0 => new Intl.Locale(x0),
      tE: (o, p, r) => o.replace(p, () => r),
      tF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tG: x0 => x0.state,
      tH: x0 => x0.clipboard,
      tI: (x0,x1) => x0.createElement(x1),
      tJ: () => globalThis.window,
      tK: x0 => x0.stopPropagation(),
      tL: (x0,x1) => x0.then(x1),
      tM: (x0,x1) => x0.sqlite3_result_null(x1),
      tN: x0 => x0.call(),
      tO: (x0,x1) => globalThis.IDBKeyRange.bound(x0,x1),
      tP: x0 => x0.repeat,
      tQ: x0 => x0.top,
      tR: (x0,x1) => { x0.accept = x1 },
      tS: x0 => x0.projectId,
      u: () => [],
      uB: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      uC: (x0,x1) => x0.createElement(x1),
      uD: x0 => x0.region,
      uE: (o, p, r) => o.replaceAll(p, () => r),
      uF: x0 => x0.now(),
      uG: x0 => x0.hash,
      uH: (x0,x1) => x0.writeText(x1),
      uI: (x0,x1) => { x0.pointerEvents = x1 },
      uJ: () => globalThis.globalThis,
      uK: x0 => x0.disabled,
      uL: x0 => x0.commit(),
      uM: (x0,x1) => x0.sqlite3_value_blob(x1),
      uN: x0 => x0.instance,
      uO: x0 => x0.length,
      uP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uQ: x0 => x0.left,
      uR: (x0,x1) => { x0.multiple = x1 },
      uS: x0 => x0.apiKey,
      v: (a, i) => a.push(i),
      vB: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      vC: x0 => x0.scale,
      vD: x0 => x0.script,
      vE: x0 => x0.deltaMode,
      vF: x0 => x0.performance,
      vG: x0 => x0.state,
      vH: x0 => x0.unlock(),
      vI: (x0,x1) => { x0.height = x1 },
      vJ: () => new Array(),
      vK: (x0,x1) => { x0.min = x1 },
      vL: x0 => x0.abort(),
      vM: (x0,x1) => x0.sqlite3_value_bytes(x1),
      vN: (x0,x1,x2) => x0.instantiateStreaming(x1,x2),
      vO: (x0,x1) => x0.get(x1),
      vP: x0 => x0.userAgent,
      vQ: (x0,x1) => x0.warn(x1),
      vR: (x0,x1) => { x0.type = x1 },
      vS: x0 => x0.options,
      w: x0 => new Int8Array(x0),
      wB: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      wC: x0 => x0.visualViewport,
      wD: x0 => x0.language,
      wE: x0 => x0.deltaY,
      wF: (a, i) => a.splice(i, 1),
      wG: (x0,x1) => x0.go(x1),
      wH: (x0,x1) => x0.lock(x1),
      wI: (x0,x1) => { x0.width = x1 },
      wJ: (x0,x1) => new WebSocket(x0,x1),
      wK: (x0,x1) => { x0.max = x1 },
      wL: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      wM: (x0,x1) => x0.sqlite3_value_text(x1),
      wN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wO: (x0,x1) => x0.index(x1),
      wP: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      wQ: () => globalThis.console,
      wR: (x0,x1) => x0.getAttribute(x1),
      wS: x0 => x0.name,
      x: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      xB: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      xC: x0 => x0.devicePixelRatio,
      xD: x0 => x0.languages,
      xE: x0 => x0.deltaX,
      xF: a => a.pop(),
      xG: (a, l) => a.length = l,
      xH: x0 => x0.orientation,
      xI: x0 => x0.style,
      xJ: x0 => x0.reason,
      xK: (x0,x1) => { x0.disabled = x1 },
      xL: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      xM: (x0,x1) => x0.sqlite3_value_double(x1),
      xN: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      xO: x0 => x0.openKeyCursor(),
      xP: (x0,x1) => x0.key(x1),
      xQ: (x0,x1) => x0.querySelectorAll(x1),
      xR: (x0,x1) => x0.debug(x1),
      xS: () => globalThis.firebase_core.getApps(),
      y: x0 => new Uint8Array(x0),
      yB: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      yC: x0 => x0.height,
      yD: (x0,x1) => x0.observe(x1),
      yE: x0 => x0.wheelDeltaY,
      yF: (map, o, v) => map.set(o, v),
      yG: x0 => x0.parentElement,
      yH: (x0,x1) => x0.querySelector(x1),
      yI: (x0,x1) => { x0.src = x1 },
      yJ: x0 => x0.code,
      yK: (x0,x1) => { x0.scrollLeft = x1 },
      yL: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      yM: (x0,x1) => x0.sqlite3_value_int64(x1),
      yN: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3,x4) { return wasmFunction(f,arguments.length,x0,x1,x2,x3,x4) }),
      yO: x0 => x0.primaryKey,
      yP: x0 => x0.length,
      yQ: (x0,x1) => x0.contains(x1),
      yR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      yS: x0 => x0.name,
      z: x0 => new Uint8ClampedArray(x0),
      zB: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      zC: x0 => x0.width,
      zD: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      zE: x0 => x0.wheelDeltaX,
      zF: (map, o) => map.get(o),
      zG: (x0,x1) => x0.querySelectorAll(x1),
      zH: (x0,x1) => { x0.title = x1 },
      zI: () => globalThis.document,
      zJ: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      zK: (x0,x1) => { x0.spellcheck = x1 },
      zL: (x0,x1) => { x0.onerror = x1 },
      zM: (x0,x1) => x0.sqlite3_value_type(x1),
      zN: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      zO: (x0,x1,x2) => x0.open(x1,x2),
      zP: (x0,x1,x2,x3) => x0.identify(x1,x2,x3),
      zQ: (x0,x1) => x0.querySelectorAll(x1),
      zR: x0 => ({createScriptURL: x0}),
      zS: (x0,x1,x2) => x0.addEventListener(x1,x2),

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
