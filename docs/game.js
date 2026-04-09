
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
  loadPackage({"package_uuid":"92b7de85-7506-4a62-bff4-8a631c3c7408","remote_package_size":77596105,"files":[{"filename":"/.gitignore","crunched":0,"start":0,"end":85,"audio":false},{"filename":"/.gitmodules","crunched":0,"start":85,"end":157,"audio":false},{"filename":"/.luarc.config","crunched":0,"start":157,"end":465,"audio":false},{"filename":"/NotoSans-VariableFont_wdth,wght.ttf","crunched":0,"start":465,"end":2045013,"audio":false},{"filename":"/README.md","crunched":0,"start":2045013,"end":2047298,"audio":false},{"filename":"/SUIT/.gitignore","crunched":0,"start":2047298,"end":2047314,"audio":false},{"filename":"/SUIT/README.md","crunched":0,"start":2047314,"end":2049202,"audio":false},{"filename":"/SUIT/button.lua","crunched":0,"start":2049202,"end":2049900,"audio":false},{"filename":"/SUIT/checkbox.lua","crunched":0,"start":2049900,"end":2050723,"audio":false},{"filename":"/SUIT/core.lua","crunched":0,"start":2050723,"end":2055252,"audio":false},{"filename":"/SUIT/docs/Makefile","crunched":0,"start":2055252,"end":2062653,"audio":false},{"filename":"/SUIT/docs/_static/demo.gif","crunched":0,"start":2062653,"end":3387007,"audio":false},{"filename":"/SUIT/docs/_static/different-ids.gif","crunched":0,"start":3387007,"end":3687274,"audio":false},{"filename":"/SUIT/docs/_static/hello-world.gif","crunched":0,"start":3687274,"end":3735803,"audio":false},{"filename":"/SUIT/docs/_static/keyboard.gif","crunched":0,"start":3735803,"end":3745096,"audio":false},{"filename":"/SUIT/docs/_static/layout.gif","crunched":0,"start":3745096,"end":3805446,"audio":false},{"filename":"/SUIT/docs/_static/mutable-state.gif","crunched":0,"start":3805446,"end":3885048,"audio":false},{"filename":"/SUIT/docs/_static/options.gif","crunched":0,"start":3885048,"end":3937042,"audio":false},{"filename":"/SUIT/docs/_static/same-ids.gif","crunched":0,"start":3937042,"end":4282964,"audio":false},{"filename":"/SUIT/docs/conf.py","crunched":0,"start":4282964,"end":4292300,"audio":false},{"filename":"/SUIT/docs/core.rst","crunched":0,"start":4292300,"end":4298522,"audio":false},{"filename":"/SUIT/docs/gettingstarted.rst","crunched":0,"start":4298522,"end":4312826,"audio":false},{"filename":"/SUIT/docs/index.rst","crunched":0,"start":4312826,"end":4321591,"audio":false},{"filename":"/SUIT/docs/layout.rst","crunched":0,"start":4321591,"end":4330135,"audio":false},{"filename":"/SUIT/docs/license.rst","crunched":0,"start":4330135,"end":4331435,"audio":false},{"filename":"/SUIT/docs/themes.rst","crunched":0,"start":4331435,"end":4331487,"audio":false},{"filename":"/SUIT/docs/widgets.rst","crunched":0,"start":4331487,"end":4337948,"audio":false},{"filename":"/SUIT/imagebutton.lua","crunched":0,"start":4337948,"end":4339603,"audio":false},{"filename":"/SUIT/init.lua","crunched":0,"start":4339603,"end":4342314,"audio":false},{"filename":"/SUIT/input.lua","crunched":0,"start":4342314,"end":4346047,"audio":false},{"filename":"/SUIT/label.lua","crunched":0,"start":4346047,"end":4346744,"audio":false},{"filename":"/SUIT/layout.lua","crunched":0,"start":4346744,"end":4355455,"audio":false},{"filename":"/SUIT/license.txt","crunched":0,"start":4355455,"end":4356738,"audio":false},{"filename":"/SUIT/slider.lua","crunched":0,"start":4356738,"end":4358346,"audio":false},{"filename":"/SUIT/suit-0.1-1.rockspec","crunched":0,"start":4358346,"end":4359008,"audio":false},{"filename":"/SUIT/theme.lua","crunched":0,"start":4359008,"end":4363604,"audio":false},{"filename":"/assets/Pirates Red Sprite Sheet.png","crunched":0,"start":4363604,"end":4382294,"audio":false},{"filename":"/assets/Pirates Yellow Sprite Sheet.png","crunched":0,"start":4382294,"end":4400936,"audio":false},{"filename":"/assets/PixelifySans-SemiBold.ttf","crunched":0,"start":4400936,"end":4452036,"audio":false},{"filename":"/assets/boat.png","crunched":0,"start":4452036,"end":4488863,"audio":false},{"filename":"/assets/fish-icon.png","crunched":0,"start":4488863,"end":4490297,"audio":false},{"filename":"/assets/food.avif","crunched":0,"start":4490297,"end":4493694,"audio":false},{"filename":"/assets/lightning_strike.ogg","crunched":0,"start":4493694,"end":4510967,"audio":true},{"filename":"/assets/rain.ogg","crunched":0,"start":4510967,"end":4531841,"audio":true},{"filename":"/assets/salmon.jpg","crunched":0,"start":4531841,"end":4552373,"audio":false},{"filename":"/assets/shopkeeper.png","crunched":0,"start":4552373,"end":4553084,"audio":false},{"filename":"/assets/shore.png","crunched":0,"start":4553084,"end":4581684,"audio":false},{"filename":"/assets/sleeping.png","crunched":0,"start":4581684,"end":4582664,"audio":false},{"filename":"/assets/wave.png","crunched":0,"start":4582664,"end":4585104,"audio":false},{"filename":"/build_web.sh","crunched":0,"start":4585104,"end":4589068,"audio":false},{"filename":"/conf.lua","crunched":0,"start":4589068,"end":4590982,"audio":false},{"filename":"/deploy_pages.sh","crunched":0,"start":4590982,"end":4591600,"audio":false},{"filename":"/docs/.nojekyll","crunched":0,"start":4591600,"end":4591600,"audio":false},{"filename":"/docs/game.data","crunched":0,"start":4591600,"end":62780787,"audio":false},{"filename":"/docs/game.js","crunched":0,"start":62780787,"end":62805019,"audio":false},{"filename":"/docs/index.html","crunched":0,"start":62805019,"end":62805490,"audio":false},{"filename":"/docs/index_weird.html","crunched":0,"start":62805490,"end":62818333,"audio":false},{"filename":"/docs/love.js","crunched":0,"start":62818333,"end":63143787,"audio":false},{"filename":"/docs/love.wasm","crunched":0,"start":63143787,"end":67864513,"audio":false},{"filename":"/docs/theme/bg.png","crunched":0,"start":67864513,"end":67871674,"audio":false},{"filename":"/docs/theme/love.css","crunched":0,"start":67871674,"end":67872534,"audio":false},{"filename":"/game/action_display.lua","crunched":0,"start":67872534,"end":67887755,"audio":false},{"filename":"/game/alert.lua","crunched":0,"start":67887755,"end":67891451,"audio":false},{"filename":"/game/combat.lua","crunched":0,"start":67891451,"end":67897685,"audio":false},{"filename":"/game/constants.lua","crunched":0,"start":67897685,"end":67904035,"audio":false},{"filename":"/game/crew_management.lua","crunched":0,"start":67904035,"end":67909983,"audio":false},{"filename":"/game/draw_steps.lua","crunched":0,"start":67909983,"end":67946070,"audio":false},{"filename":"/game/extra_math.lua","crunched":0,"start":67946070,"end":67948746,"audio":false},{"filename":"/game/fishing/core.lua","crunched":0,"start":67948746,"end":67957793,"audio":false},{"filename":"/game/fishing/minigame.lua","crunched":0,"start":67957793,"end":67979251,"audio":false},{"filename":"/game/fishing/runtime.lua","crunched":0,"start":67979251,"end":67984790,"audio":false},{"filename":"/game/fishing.lua","crunched":0,"start":67984790,"end":67985326,"audio":false},{"filename":"/game/fishing_minigame.lua","crunched":0,"start":67985326,"end":67985390,"audio":false},{"filename":"/game/fishing_runtime.lua","crunched":0,"start":67985390,"end":67985565,"audio":false},{"filename":"/game/gamestate.lua","crunched":0,"start":67985565,"end":67985950,"audio":false},{"filename":"/game/gametypes.lua","crunched":0,"start":67985950,"end":67986242,"audio":false},{"filename":"/game/hunger.lua","crunched":0,"start":67986242,"end":68000662,"audio":false},{"filename":"/game/mobile_controls_steps.lua","crunched":0,"start":68000662,"end":68003816,"audio":false},{"filename":"/game/mod_terminal.lua","crunched":0,"start":68003816,"end":68028880,"audio":false},{"filename":"/game/mods.lua","crunched":0,"start":68028880,"end":68035294,"audio":false},{"filename":"/game/morningtext.lua","crunched":0,"start":68035294,"end":68048389,"audio":false},{"filename":"/game/movement_steps.lua","crunched":0,"start":68048389,"end":68062115,"audio":false},{"filename":"/game/ripple_steps.lua","crunched":0,"start":68062115,"end":68067105,"audio":false},{"filename":"/game/scrolling.lua","crunched":0,"start":68067105,"end":68075416,"audio":false},{"filename":"/game/serialize.lua","crunched":0,"start":68075416,"end":68081719,"audio":false},{"filename":"/game/shaders.lua","crunched":0,"start":68081719,"end":68086634,"audio":false},{"filename":"/game/shopkeeper.lua","crunched":0,"start":68086634,"end":68092199,"audio":false},{"filename":"/game/size.lua","crunched":0,"start":68092199,"end":68092746,"audio":false},{"filename":"/game/spawnenemy.lua","crunched":0,"start":68092746,"end":68112557,"audio":false},{"filename":"/game/state.lua","crunched":0,"start":68112557,"end":68117539,"audio":false},{"filename":"/game/storm.lua","crunched":0,"start":68117539,"end":68133226,"audio":false},{"filename":"/game/suit_theme.lua","crunched":0,"start":68133226,"end":68139150,"audio":false},{"filename":"/game/time_utils.lua","crunched":0,"start":68139150,"end":68140294,"audio":false},{"filename":"/game/top.lua","crunched":0,"start":68140294,"end":68151607,"audio":false},{"filename":"/game/update_steps.lua","crunched":0,"start":68151607,"end":68172345,"audio":false},{"filename":"/game/visuals.lua","crunched":0,"start":68172345,"end":68175291,"audio":false},{"filename":"/game/wake_up.lua","crunched":0,"start":68175291,"end":68178432,"audio":false},{"filename":"/game.lua","crunched":0,"start":68178432,"end":68220294,"audio":false},{"filename":"/host.sh","crunched":0,"start":68220294,"end":68226533,"audio":false},{"filename":"/index_weird.html","crunched":0,"start":68226533,"end":68239376,"audio":false},{"filename":"/lowercase.py","crunched":0,"start":68239376,"end":68240286,"audio":false},{"filename":"/main.lua","crunched":0,"start":68240286,"end":68249960,"audio":false},{"filename":"/menu.lua","crunched":0,"start":68249960,"end":68258785,"audio":false},{"filename":"/mods/first_tick.txt","crunched":0,"start":68258785,"end":68258811,"audio":false},{"filename":"/mods/mod_log.txt","crunched":0,"start":68258811,"end":68271018,"audio":false},{"filename":"/mods_ex/always_200_fishing_score.lua","crunched":0,"start":68271018,"end":68272717,"audio":false},{"filename":"/mods_ex/fishing_100_coins.lua","crunched":0,"start":68272717,"end":68274927,"audio":false},{"filename":"/mods_ex/no_dangerous_zones.lua","crunched":0,"start":68274927,"end":68275437,"audio":false},{"filename":"/sand.lua","crunched":0,"start":68275437,"end":68284985,"audio":false},{"filename":"/scripts/divisions.py","crunched":0,"start":68284985,"end":68287113,"audio":false},{"filename":"/scripts/econ_math.lua","crunched":0,"start":68287113,"end":68294480,"audio":false},{"filename":"/scripts/econ_math_output.csv","crunched":0,"start":68294480,"end":68295876,"audio":false},{"filename":"/scripts/hex2love.lua","crunched":0,"start":68295876,"end":68297122,"audio":false},{"filename":"/shop/controller.lua","crunched":0,"start":68297122,"end":68303911,"audio":false},{"filename":"/shop/economy.lua","crunched":0,"start":68303911,"end":68308305,"audio":false},{"filename":"/shop/inventory_utils.lua","crunched":0,"start":68308305,"end":68308981,"audio":false},{"filename":"/shop/port.lua","crunched":0,"start":68308981,"end":68352214,"audio":false},{"filename":"/shop/state.lua","crunched":0,"start":68352214,"end":68353245,"audio":false},{"filename":"/shop/ui/inventory.lua","crunched":0,"start":68353245,"end":68358183,"audio":false},{"filename":"/shop/ui/main.lua","crunched":0,"start":68358183,"end":68371283,"audio":false},{"filename":"/shop/ui/transfer.lua","crunched":0,"start":68371283,"end":68376739,"audio":false},{"filename":"/shop.lua","crunched":0,"start":68376739,"end":68377560,"audio":false},{"filename":"/voyage.love","crunched":0,"start":68377560,"end":77596105,"audio":false}]});

})();
