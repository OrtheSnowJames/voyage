
var Module;

if (typeof Module === 'undefined') Module = eval('(function() { try { return Module || {} } catch(e) { return {} } })()');

if (!Module.expectedDataFileDownloads) {
  Module.expectedDataFileDownloads = 0;
  Module.finishedDataFileDownloads = 0;
}
Module.expectedDataFileDownloads++;
(function() {
 var loadPackage = function(metadata) {

  var PACKAGE_PATH;
  if (typeof window === 'object') {
    PACKAGE_PATH = window['encodeURIComponent'](window.location.pathname.toString().substring(0, window.location.pathname.toString().lastIndexOf('/')) + '/');
  } else if (typeof location !== 'undefined') {
      // worker
      PACKAGE_PATH = encodeURIComponent(location.pathname.toString().substring(0, location.pathname.toString().lastIndexOf('/')) + '/');
    } else {
      throw 'using preloaded data can only be done on a web page or in a web worker';
    }
    var PACKAGE_NAME = 'game.data';
    var REMOTE_PACKAGE_BASE = 'game.data';
    if (typeof Module['locateFilePackage'] === 'function' && !Module['locateFile']) {
      Module['locateFile'] = Module['locateFilePackage'];
      Module.printErr('warning: you defined Module.locateFilePackage, that has been renamed to Module.locateFile (using your locateFilePackage for now)');
    }
    var REMOTE_PACKAGE_NAME = typeof Module['locateFile'] === 'function' ?
    Module['locateFile'](REMOTE_PACKAGE_BASE) :
    ((Module['filePackagePrefixURL'] || '') + REMOTE_PACKAGE_BASE);

    var REMOTE_PACKAGE_SIZE = metadata.remote_package_size;
    var PACKAGE_UUID = metadata.package_uuid;

    function fetchRemotePackage(packageName, packageSize, callback, errback) {
      var xhr = new XMLHttpRequest();
      xhr.open('GET', packageName, true);
      xhr.responseType = 'arraybuffer';
      xhr.onprogress = function(event) {
        var url = packageName;
        var size = packageSize;
        if (event.total) size = event.total;
        if (event.loaded) {
          if (!xhr.addedTotal) {
            xhr.addedTotal = true;
            if (!Module.dataFileDownloads) Module.dataFileDownloads = {};
            Module.dataFileDownloads[url] = {
              loaded: event.loaded,
              total: size
            };
          } else {
            Module.dataFileDownloads[url].loaded = event.loaded;
          }
          var total = 0;
          var loaded = 0;
          var num = 0;
          for (var download in Module.dataFileDownloads) {
            var data = Module.dataFileDownloads[download];
            total += data.total;
            loaded += data.loaded;
            num++;
          }
          total = Math.ceil(total * Module.expectedDataFileDownloads/num);
          if (Module['setStatus']) Module['setStatus']('Downloading data... (' + loaded + '/' + total + ')');
        } else if (!Module.dataFileDownloads) {
          if (Module['setStatus']) Module['setStatus']('Downloading data...');
        }
      };
      xhr.onerror = function(event) {
        throw new Error("NetworkError for: " + packageName);
      }
      xhr.onload = function(event) {
        if (xhr.status == 200 || xhr.status == 304 || xhr.status == 206 || (xhr.status == 0 && xhr.response)) { // file URLs can return 0
          var packageData = xhr.response;
          callback(packageData);
        } else {
          throw new Error(xhr.statusText + " : " + xhr.responseURL);
        }
      };
      xhr.send(null);
    };

    function handleError(error) {
      console.error('package error:', error);
    };

    function runWithFS() {

      function assert(check, msg) {
        if (!check) throw msg + new Error().stack;
      }
      Module['FS_createPath']('/', 'SUIT', true, true);
      Module['FS_createPath']('/SUIT', 'docs', true, true);
      Module['FS_createPath']('/SUIT/docs', '_static', true, true);
      Module['FS_createPath']('/', 'assets', true, true);
      Module['FS_createPath']('/', 'docs', true, true);
      Module['FS_createPath']('/docs', 'theme', true, true);
      Module['FS_createPath']('/', 'game', true, true);
      Module['FS_createPath']('/game', 'fishing', true, true);
      Module['FS_createPath']('/', 'mods', true, true);
      Module['FS_createPath']('/', 'mods_ex', true, true);
      Module['FS_createPath']('/', 'scripts', true, true);
      Module['FS_createPath']('/', 'shop', true, true);
      Module['FS_createPath']('/shop', 'ui', true, true);

      function DataRequest(start, end, crunched, audio) {
        this.start = start;
        this.end = end;
        this.crunched = crunched;
        this.audio = audio;
      }
      DataRequest.prototype = {
        requests: {},
        open: function(mode, name) {
          this.name = name;
          this.requests[name] = this;
          Module['addRunDependency']('fp ' + this.name);
        },
        send: function() {},
        onload: function() {
          var byteArray = this.byteArray.subarray(this.start, this.end);

          this.finish(byteArray);

        },
        finish: function(byteArray) {
          var that = this;

        Module['FS_createDataFile'](this.name, null, byteArray, true, true, true); // canOwn this data in the filesystem, it is a slide into the heap that will never change
        Module['removeRunDependency']('fp ' + that.name);

        this.requests[this.name] = null;
      }
    };

    var files = metadata.files;
    for (i = 0; i < files.length; ++i) {
      new DataRequest(files[i].start, files[i].end, files[i].crunched, files[i].audio).open('GET', files[i].filename);
    }


    var indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
    var IDB_RO = "readonly";
    var IDB_RW = "readwrite";
    var DB_NAME = "EM_PRELOAD_CACHE";
    var DB_VERSION = 1;
    var METADATA_STORE_NAME = 'METADATA';
    var PACKAGE_STORE_NAME = 'PACKAGES';
    function openDatabase(callback, errback) {
      try {
        var openRequest = indexedDB.open(DB_NAME, DB_VERSION);
      } catch (e) {
        return errback(e);
      }
      openRequest.onupgradeneeded = function(event) {
        var db = event.target.result;

        if(db.objectStoreNames.contains(PACKAGE_STORE_NAME)) {
          db.deleteObjectStore(PACKAGE_STORE_NAME);
        }
        var packages = db.createObjectStore(PACKAGE_STORE_NAME);

        if(db.objectStoreNames.contains(METADATA_STORE_NAME)) {
          db.deleteObjectStore(METADATA_STORE_NAME);
        }
        var metadata = db.createObjectStore(METADATA_STORE_NAME);
      };
      openRequest.onsuccess = function(event) {
        var db = event.target.result;
        callback(db);
      };
      openRequest.onerror = function(error) {
        errback(error);
      };
    };

    /* Check if there's a cached package, and if so whether it's the latest available */
    function checkCachedPackage(db, packageName, callback, errback) {
      var transaction = db.transaction([METADATA_STORE_NAME], IDB_RO);
      var metadata = transaction.objectStore(METADATA_STORE_NAME);

      var getRequest = metadata.get("metadata/" + packageName);
      getRequest.onsuccess = function(event) {
        var result = event.target.result;
        if (!result) {
          return callback(false);
        } else {
          return callback(PACKAGE_UUID === result.uuid);
        }
      };
      getRequest.onerror = function(error) {
        errback(error);
      };
    };

    function fetchCachedPackage(db, packageName, callback, errback) {
      var transaction = db.transaction([PACKAGE_STORE_NAME], IDB_RO);
      var packages = transaction.objectStore(PACKAGE_STORE_NAME);

      var getRequest = packages.get("package/" + packageName);
      getRequest.onsuccess = function(event) {
        var result = event.target.result;
        callback(result);
      };
      getRequest.onerror = function(error) {
        errback(error);
      };
    };

    function cacheRemotePackage(db, packageName, packageData, packageMeta, callback, errback) {
      var transaction_packages = db.transaction([PACKAGE_STORE_NAME], IDB_RW);
      var packages = transaction_packages.objectStore(PACKAGE_STORE_NAME);

      var putPackageRequest = packages.put(packageData, "package/" + packageName);
      putPackageRequest.onsuccess = function(event) {
        var transaction_metadata = db.transaction([METADATA_STORE_NAME], IDB_RW);
        var metadata = transaction_metadata.objectStore(METADATA_STORE_NAME);
        var putMetadataRequest = metadata.put(packageMeta, "metadata/" + packageName);
        putMetadataRequest.onsuccess = function(event) {
          callback(packageData);
        };
        putMetadataRequest.onerror = function(error) {
          errback(error);
        };
      };
      putPackageRequest.onerror = function(error) {
        errback(error);
      };
    };

    function processPackageData(arrayBuffer) {
      Module.finishedDataFileDownloads++;
      assert(arrayBuffer, 'Loading data file failed.');
      assert(arrayBuffer instanceof ArrayBuffer, 'bad input to processPackageData');
      var byteArray = new Uint8Array(arrayBuffer);
      var curr;

        // copy the entire loaded file into a spot in the heap. Files will refer to slices in that. They cannot be freed though
        // (we may be allocating before malloc is ready, during startup).
        if (Module['SPLIT_MEMORY']) Module.printErr('warning: you should run the file packager with --no-heap-copy when SPLIT_MEMORY is used, otherwise copying into the heap may fail due to the splitting');
        var ptr = Module['getMemory'](byteArray.length);
        Module['HEAPU8'].set(byteArray, ptr);
        DataRequest.prototype.byteArray = Module['HEAPU8'].subarray(ptr, ptr+byteArray.length);

        var files = metadata.files;
        for (i = 0; i < files.length; ++i) {
          DataRequest.prototype.requests[files[i].filename].onload();
        }
        Module['removeRunDependency']('datafile_game.data');

      };
      Module['addRunDependency']('datafile_game.data');

      if (!Module.preloadResults) Module.preloadResults = {};

      function preloadFallback(error) {
        console.error(error);
        console.error('falling back to default preload behavior');
        fetchRemotePackage(REMOTE_PACKAGE_NAME, REMOTE_PACKAGE_SIZE, processPackageData, handleError);
      };

      openDatabase(
        function(db) {
          checkCachedPackage(db, PACKAGE_PATH + PACKAGE_NAME,
            function(useCached) {
              Module.preloadResults[PACKAGE_NAME] = {fromCache: useCached};
              if (useCached) {
                console.info('loading ' + PACKAGE_NAME + ' from cache');
                fetchCachedPackage(db, PACKAGE_PATH + PACKAGE_NAME, processPackageData, preloadFallback);
              } else {
                console.info('loading ' + PACKAGE_NAME + ' from remote');
                fetchRemotePackage(REMOTE_PACKAGE_NAME, REMOTE_PACKAGE_SIZE,
                  function(packageData) {
                    cacheRemotePackage(db, PACKAGE_PATH + PACKAGE_NAME, packageData, {uuid:PACKAGE_UUID}, processPackageData,
                      function(error) {
                        console.error(error);
                        processPackageData(packageData);
                      });
                  }
                  , preloadFallback);
              }
            }
            , preloadFallback);
        }
        , preloadFallback);

      if (Module['setStatus']) Module['setStatus']('Downloading...');

    }
    if (Module['calledRun']) {
      runWithFS();
    } else {
      if (!Module['preRun']) Module['preRun'] = [];
      Module["preRun"].push(runWithFS); // FS is not initialized yet, wait for it
    }

  }
  loadPackage({"package_uuid":"7e122903-f19d-43f8-832f-8f1b19a915d6","remote_package_size":19406757,"files":[{"filename":"/.gitignore","crunched":0,"start":0,"end":85,"audio":false},{"filename":"/.gitmodules","crunched":0,"start":85,"end":157,"audio":false},{"filename":"/.luarc.config","crunched":0,"start":157,"end":465,"audio":false},{"filename":"/NotoSans-VariableFont_wdth,wght.ttf","crunched":0,"start":465,"end":2045013,"audio":false},{"filename":"/README.md","crunched":0,"start":2045013,"end":2047298,"audio":false},{"filename":"/SUIT/.gitignore","crunched":0,"start":2047298,"end":2047314,"audio":false},{"filename":"/SUIT/README.md","crunched":0,"start":2047314,"end":2049202,"audio":false},{"filename":"/SUIT/button.lua","crunched":0,"start":2049202,"end":2049900,"audio":false},{"filename":"/SUIT/checkbox.lua","crunched":0,"start":2049900,"end":2050723,"audio":false},{"filename":"/SUIT/core.lua","crunched":0,"start":2050723,"end":2055252,"audio":false},{"filename":"/SUIT/docs/Makefile","crunched":0,"start":2055252,"end":2062653,"audio":false},{"filename":"/SUIT/docs/_static/demo.gif","crunched":0,"start":2062653,"end":3387007,"audio":false},{"filename":"/SUIT/docs/_static/different-ids.gif","crunched":0,"start":3387007,"end":3687274,"audio":false},{"filename":"/SUIT/docs/_static/hello-world.gif","crunched":0,"start":3687274,"end":3735803,"audio":false},{"filename":"/SUIT/docs/_static/keyboard.gif","crunched":0,"start":3735803,"end":3745096,"audio":false},{"filename":"/SUIT/docs/_static/layout.gif","crunched":0,"start":3745096,"end":3805446,"audio":false},{"filename":"/SUIT/docs/_static/mutable-state.gif","crunched":0,"start":3805446,"end":3885048,"audio":false},{"filename":"/SUIT/docs/_static/options.gif","crunched":0,"start":3885048,"end":3937042,"audio":false},{"filename":"/SUIT/docs/_static/same-ids.gif","crunched":0,"start":3937042,"end":4282964,"audio":false},{"filename":"/SUIT/docs/conf.py","crunched":0,"start":4282964,"end":4292300,"audio":false},{"filename":"/SUIT/docs/core.rst","crunched":0,"start":4292300,"end":4298522,"audio":false},{"filename":"/SUIT/docs/gettingstarted.rst","crunched":0,"start":4298522,"end":4312826,"audio":false},{"filename":"/SUIT/docs/index.rst","crunched":0,"start":4312826,"end":4321591,"audio":false},{"filename":"/SUIT/docs/layout.rst","crunched":0,"start":4321591,"end":4330135,"audio":false},{"filename":"/SUIT/docs/license.rst","crunched":0,"start":4330135,"end":4331435,"audio":false},{"filename":"/SUIT/docs/themes.rst","crunched":0,"start":4331435,"end":4331487,"audio":false},{"filename":"/SUIT/docs/widgets.rst","crunched":0,"start":4331487,"end":4337948,"audio":false},{"filename":"/SUIT/imagebutton.lua","crunched":0,"start":4337948,"end":4339603,"audio":false},{"filename":"/SUIT/init.lua","crunched":0,"start":4339603,"end":4342314,"audio":false},{"filename":"/SUIT/input.lua","crunched":0,"start":4342314,"end":4346047,"audio":false},{"filename":"/SUIT/label.lua","crunched":0,"start":4346047,"end":4346744,"audio":false},{"filename":"/SUIT/layout.lua","crunched":0,"start":4346744,"end":4355455,"audio":false},{"filename":"/SUIT/license.txt","crunched":0,"start":4355455,"end":4356738,"audio":false},{"filename":"/SUIT/slider.lua","crunched":0,"start":4356738,"end":4358346,"audio":false},{"filename":"/SUIT/suit-0.1-1.rockspec","crunched":0,"start":4358346,"end":4359008,"audio":false},{"filename":"/SUIT/theme.lua","crunched":0,"start":4359008,"end":4363604,"audio":false},{"filename":"/assets/Pirates Red Sprite Sheet.png","crunched":0,"start":4363604,"end":4382294,"audio":false},{"filename":"/assets/Pirates Yellow Sprite Sheet.png","crunched":0,"start":4382294,"end":4400936,"audio":false},{"filename":"/assets/PixelifySans-SemiBold.ttf","crunched":0,"start":4400936,"end":4452036,"audio":false},{"filename":"/assets/boat.png","crunched":0,"start":4452036,"end":4488863,"audio":false},{"filename":"/assets/fish-icon.png","crunched":0,"start":4488863,"end":4490297,"audio":false},{"filename":"/assets/food.avif","crunched":0,"start":4490297,"end":4493694,"audio":false},{"filename":"/assets/lightning_strike.ogg","crunched":0,"start":4493694,"end":4510967,"audio":true},{"filename":"/assets/rain.ogg","crunched":0,"start":4510967,"end":4531841,"audio":true},{"filename":"/assets/salmon.jpg","crunched":0,"start":4531841,"end":4552373,"audio":false},{"filename":"/assets/shopkeeper.png","crunched":0,"start":4552373,"end":4553084,"audio":false},{"filename":"/assets/shore.png","crunched":0,"start":4553084,"end":4581684,"audio":false},{"filename":"/assets/sleeping.png","crunched":0,"start":4581684,"end":4582664,"audio":false},{"filename":"/assets/wave.png","crunched":0,"start":4582664,"end":4585104,"audio":false},{"filename":"/build_web.sh","crunched":0,"start":4585104,"end":4589068,"audio":false},{"filename":"/conf.lua","crunched":0,"start":4589068,"end":4590982,"audio":false},{"filename":"/deploy_pages.sh","crunched":0,"start":4590982,"end":4591600,"audio":false},{"filename":"/docs/.nojekyll","crunched":0,"start":4591600,"end":4591600,"audio":false},{"filename":"/docs/game.js","crunched":0,"start":4591600,"end":4615217,"audio":false},{"filename":"/docs/index.html","crunched":0,"start":4615217,"end":4615688,"audio":false},{"filename":"/docs/index_weird.html","crunched":0,"start":4615688,"end":4628531,"audio":false},{"filename":"/docs/love.js","crunched":0,"start":4628531,"end":4953985,"audio":false},{"filename":"/docs/love.wasm","crunched":0,"start":4953985,"end":9674711,"audio":false},{"filename":"/docs/theme/bg.png","crunched":0,"start":9674711,"end":9681872,"audio":false},{"filename":"/docs/theme/love.css","crunched":0,"start":9681872,"end":9682732,"audio":false},{"filename":"/game/action_display.lua","crunched":0,"start":9682732,"end":9697953,"audio":false},{"filename":"/game/alert.lua","crunched":0,"start":9697953,"end":9701649,"audio":false},{"filename":"/game/combat.lua","crunched":0,"start":9701649,"end":9707883,"audio":false},{"filename":"/game/constants.lua","crunched":0,"start":9707883,"end":9714233,"audio":false},{"filename":"/game/crew_management.lua","crunched":0,"start":9714233,"end":9720181,"audio":false},{"filename":"/game/draw_steps.lua","crunched":0,"start":9720181,"end":9756268,"audio":false},{"filename":"/game/extra_math.lua","crunched":0,"start":9756268,"end":9758944,"audio":false},{"filename":"/game/fishing/core.lua","crunched":0,"start":9758944,"end":9767991,"audio":false},{"filename":"/game/fishing/minigame.lua","crunched":0,"start":9767991,"end":9789903,"audio":false},{"filename":"/game/fishing/runtime.lua","crunched":0,"start":9789903,"end":9795442,"audio":false},{"filename":"/game/fishing.lua","crunched":0,"start":9795442,"end":9795978,"audio":false},{"filename":"/game/fishing_minigame.lua","crunched":0,"start":9795978,"end":9796042,"audio":false},{"filename":"/game/fishing_runtime.lua","crunched":0,"start":9796042,"end":9796217,"audio":false},{"filename":"/game/gamestate.lua","crunched":0,"start":9796217,"end":9796602,"audio":false},{"filename":"/game/gametypes.lua","crunched":0,"start":9796602,"end":9796894,"audio":false},{"filename":"/game/hunger.lua","crunched":0,"start":9796894,"end":9811314,"audio":false},{"filename":"/game/mobile_controls_steps.lua","crunched":0,"start":9811314,"end":9814468,"audio":false},{"filename":"/game/mod_terminal.lua","crunched":0,"start":9814468,"end":9839532,"audio":false},{"filename":"/game/mods.lua","crunched":0,"start":9839532,"end":9845946,"audio":false},{"filename":"/game/morningtext.lua","crunched":0,"start":9845946,"end":9859041,"audio":false},{"filename":"/game/movement_steps.lua","crunched":0,"start":9859041,"end":9872767,"audio":false},{"filename":"/game/ripple_steps.lua","crunched":0,"start":9872767,"end":9877757,"audio":false},{"filename":"/game/scrolling.lua","crunched":0,"start":9877757,"end":9886068,"audio":false},{"filename":"/game/serialize.lua","crunched":0,"start":9886068,"end":9892371,"audio":false},{"filename":"/game/shaders.lua","crunched":0,"start":9892371,"end":9897286,"audio":false},{"filename":"/game/shopkeeper.lua","crunched":0,"start":9897286,"end":9902851,"audio":false},{"filename":"/game/size.lua","crunched":0,"start":9902851,"end":9903398,"audio":false},{"filename":"/game/spawnenemy.lua","crunched":0,"start":9903398,"end":9923209,"audio":false},{"filename":"/game/state.lua","crunched":0,"start":9923209,"end":9928191,"audio":false},{"filename":"/game/storm.lua","crunched":0,"start":9928191,"end":9943878,"audio":false},{"filename":"/game/suit_theme.lua","crunched":0,"start":9943878,"end":9949802,"audio":false},{"filename":"/game/time_utils.lua","crunched":0,"start":9949802,"end":9950946,"audio":false},{"filename":"/game/top.lua","crunched":0,"start":9950946,"end":9962259,"audio":false},{"filename":"/game/update_steps.lua","crunched":0,"start":9962259,"end":9982997,"audio":false},{"filename":"/game/visuals.lua","crunched":0,"start":9982997,"end":9985943,"audio":false},{"filename":"/game/wake_up.lua","crunched":0,"start":9985943,"end":9989084,"audio":false},{"filename":"/game.lua","crunched":0,"start":9989084,"end":10030946,"audio":false},{"filename":"/host.sh","crunched":0,"start":10030946,"end":10037185,"audio":false},{"filename":"/index_weird.html","crunched":0,"start":10037185,"end":10050028,"audio":false},{"filename":"/lowercase.py","crunched":0,"start":10050028,"end":10050938,"audio":false},{"filename":"/main.lua","crunched":0,"start":10050938,"end":10060612,"audio":false},{"filename":"/menu.lua","crunched":0,"start":10060612,"end":10069437,"audio":false},{"filename":"/mods/first_tick.txt","crunched":0,"start":10069437,"end":10069463,"audio":false},{"filename":"/mods/mod_log.txt","crunched":0,"start":10069463,"end":10081670,"audio":false},{"filename":"/mods_ex/always_200_fishing_score.lua","crunched":0,"start":10081670,"end":10083369,"audio":false},{"filename":"/mods_ex/fishing_100_coins.lua","crunched":0,"start":10083369,"end":10085579,"audio":false},{"filename":"/mods_ex/no_dangerous_zones.lua","crunched":0,"start":10085579,"end":10086089,"audio":false},{"filename":"/sand.lua","crunched":0,"start":10086089,"end":10095637,"audio":false},{"filename":"/scripts/divisions.py","crunched":0,"start":10095637,"end":10097765,"audio":false},{"filename":"/scripts/econ_math.lua","crunched":0,"start":10097765,"end":10105132,"audio":false},{"filename":"/scripts/econ_math_output.csv","crunched":0,"start":10105132,"end":10106528,"audio":false},{"filename":"/scripts/hex2love.lua","crunched":0,"start":10106528,"end":10107774,"audio":false},{"filename":"/shop/controller.lua","crunched":0,"start":10107774,"end":10114563,"audio":false},{"filename":"/shop/economy.lua","crunched":0,"start":10114563,"end":10118957,"audio":false},{"filename":"/shop/inventory_utils.lua","crunched":0,"start":10118957,"end":10119633,"audio":false},{"filename":"/shop/port.lua","crunched":0,"start":10119633,"end":10162866,"audio":false},{"filename":"/shop/state.lua","crunched":0,"start":10162866,"end":10163897,"audio":false},{"filename":"/shop/ui/inventory.lua","crunched":0,"start":10163897,"end":10168835,"audio":false},{"filename":"/shop/ui/main.lua","crunched":0,"start":10168835,"end":10181935,"audio":false},{"filename":"/shop/ui/transfer.lua","crunched":0,"start":10181935,"end":10187391,"audio":false},{"filename":"/shop.lua","crunched":0,"start":10187391,"end":10188212,"audio":false},{"filename":"/voyage.love","crunched":0,"start":10188212,"end":19406757,"audio":false}]});

})();
