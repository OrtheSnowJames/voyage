
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
      Module['FS_createPath']('/', '..bfg-report', true, true);
      Module['FS_createPath']('/..bfg-report', '2026-04-08', true, true);
      Module['FS_createPath']('/..bfg-report/2026-04-08', '19-21-57', true, true);
      Module['FS_createPath']('/..bfg-report/2026-04-08/19-21-57', 'protected-dirt', true, true);
      Module['FS_createPath']('/', 'SUIT', true, true);
      Module['FS_createPath']('/SUIT', 'docs', true, true);
      Module['FS_createPath']('/SUIT/docs', '_static', true, true);
      Module['FS_createPath']('/', 'assets', true, true);
      Module['FS_createPath']('/', 'docs', true, true);
      Module['FS_createPath']('/docs', 'theme', true, true);
      Module['FS_createPath']('/', 'game', true, true);
      Module['FS_createPath']('/game', 'fishing', true, true);
      Module['FS_createPath']('/', 'mods', true, true);
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
  loadPackage({"package_uuid":"51303ce3-7b5a-4885-9e2c-32788620f817","remote_package_size":58189187,"files":[{"filename":"/..bfg-report/2026-04-08/19-21-57/cache-stats.txt","crunched":0,"start":0,"end":516,"audio":false},{"filename":"/..bfg-report/2026-04-08/19-21-57/deleted-files.txt","crunched":0,"start":516,"end":699,"audio":false},{"filename":"/..bfg-report/2026-04-08/19-21-57/object-id-map.old-new.txt","crunched":0,"start":699,"end":1683,"audio":false},{"filename":"/.gitignore","crunched":0,"start":1683,"end":1768,"audio":false},{"filename":"/.gitmodules","crunched":0,"start":1768,"end":1840,"audio":false},{"filename":"/.luarc.config","crunched":0,"start":1840,"end":2148,"audio":false},{"filename":"/NotoSans-VariableFont_wdth,wght.ttf","crunched":0,"start":2148,"end":2046696,"audio":false},{"filename":"/README.md","crunched":0,"start":2046696,"end":2048981,"audio":false},{"filename":"/SUIT/.gitignore","crunched":0,"start":2048981,"end":2048997,"audio":false},{"filename":"/SUIT/README.md","crunched":0,"start":2048997,"end":2050885,"audio":false},{"filename":"/SUIT/button.lua","crunched":0,"start":2050885,"end":2051583,"audio":false},{"filename":"/SUIT/checkbox.lua","crunched":0,"start":2051583,"end":2052406,"audio":false},{"filename":"/SUIT/core.lua","crunched":0,"start":2052406,"end":2056935,"audio":false},{"filename":"/SUIT/docs/Makefile","crunched":0,"start":2056935,"end":2064336,"audio":false},{"filename":"/SUIT/docs/_static/demo.gif","crunched":0,"start":2064336,"end":3388690,"audio":false},{"filename":"/SUIT/docs/_static/different-ids.gif","crunched":0,"start":3388690,"end":3688957,"audio":false},{"filename":"/SUIT/docs/_static/hello-world.gif","crunched":0,"start":3688957,"end":3737486,"audio":false},{"filename":"/SUIT/docs/_static/keyboard.gif","crunched":0,"start":3737486,"end":3746779,"audio":false},{"filename":"/SUIT/docs/_static/layout.gif","crunched":0,"start":3746779,"end":3807129,"audio":false},{"filename":"/SUIT/docs/_static/mutable-state.gif","crunched":0,"start":3807129,"end":3886731,"audio":false},{"filename":"/SUIT/docs/_static/options.gif","crunched":0,"start":3886731,"end":3938725,"audio":false},{"filename":"/SUIT/docs/_static/same-ids.gif","crunched":0,"start":3938725,"end":4284647,"audio":false},{"filename":"/SUIT/docs/conf.py","crunched":0,"start":4284647,"end":4293983,"audio":false},{"filename":"/SUIT/docs/core.rst","crunched":0,"start":4293983,"end":4300205,"audio":false},{"filename":"/SUIT/docs/gettingstarted.rst","crunched":0,"start":4300205,"end":4314509,"audio":false},{"filename":"/SUIT/docs/index.rst","crunched":0,"start":4314509,"end":4323274,"audio":false},{"filename":"/SUIT/docs/layout.rst","crunched":0,"start":4323274,"end":4331818,"audio":false},{"filename":"/SUIT/docs/license.rst","crunched":0,"start":4331818,"end":4333118,"audio":false},{"filename":"/SUIT/docs/themes.rst","crunched":0,"start":4333118,"end":4333170,"audio":false},{"filename":"/SUIT/docs/widgets.rst","crunched":0,"start":4333170,"end":4339631,"audio":false},{"filename":"/SUIT/imagebutton.lua","crunched":0,"start":4339631,"end":4341286,"audio":false},{"filename":"/SUIT/init.lua","crunched":0,"start":4341286,"end":4343997,"audio":false},{"filename":"/SUIT/input.lua","crunched":0,"start":4343997,"end":4347730,"audio":false},{"filename":"/SUIT/label.lua","crunched":0,"start":4347730,"end":4348427,"audio":false},{"filename":"/SUIT/layout.lua","crunched":0,"start":4348427,"end":4357138,"audio":false},{"filename":"/SUIT/license.txt","crunched":0,"start":4357138,"end":4358421,"audio":false},{"filename":"/SUIT/slider.lua","crunched":0,"start":4358421,"end":4360029,"audio":false},{"filename":"/SUIT/suit-0.1-1.rockspec","crunched":0,"start":4360029,"end":4360691,"audio":false},{"filename":"/SUIT/theme.lua","crunched":0,"start":4360691,"end":4365287,"audio":false},{"filename":"/assets/Pirates Red Sprite Sheet.png","crunched":0,"start":4365287,"end":4383977,"audio":false},{"filename":"/assets/Pirates Yellow Sprite Sheet.png","crunched":0,"start":4383977,"end":4402619,"audio":false},{"filename":"/assets/PixelifySans-SemiBold.ttf","crunched":0,"start":4402619,"end":4453719,"audio":false},{"filename":"/assets/boat.png","crunched":0,"start":4453719,"end":4490546,"audio":false},{"filename":"/assets/fish-icon.png","crunched":0,"start":4490546,"end":4491980,"audio":false},{"filename":"/assets/food.avif","crunched":0,"start":4491980,"end":4495377,"audio":false},{"filename":"/assets/lightning_strike.ogg","crunched":0,"start":4495377,"end":4512650,"audio":true},{"filename":"/assets/rain.ogg","crunched":0,"start":4512650,"end":4533524,"audio":true},{"filename":"/assets/salmon.jpg","crunched":0,"start":4533524,"end":4554056,"audio":false},{"filename":"/assets/shopkeeper.png","crunched":0,"start":4554056,"end":4554767,"audio":false},{"filename":"/assets/shore.png","crunched":0,"start":4554767,"end":4583367,"audio":false},{"filename":"/assets/sleeping.png","crunched":0,"start":4583367,"end":4584347,"audio":false},{"filename":"/assets/wave.png","crunched":0,"start":4584347,"end":4586787,"audio":false},{"filename":"/build_web.sh","crunched":0,"start":4586787,"end":4590751,"audio":false},{"filename":"/conf.lua","crunched":0,"start":4590751,"end":4592665,"audio":false},{"filename":"/deploy_pages.sh","crunched":0,"start":4592665,"end":4593283,"audio":false},{"filename":"/docs/.nojekyll","crunched":0,"start":4593283,"end":4593283,"audio":false},{"filename":"/docs/game.data","crunched":0,"start":4593283,"end":43381090,"audio":false},{"filename":"/docs/game.js","crunched":0,"start":43381090,"end":43404639,"audio":false},{"filename":"/docs/index.html","crunched":0,"start":43404639,"end":43405110,"audio":false},{"filename":"/docs/index_weird.html","crunched":0,"start":43405110,"end":43417953,"audio":false},{"filename":"/docs/love.js","crunched":0,"start":43417953,"end":43743407,"audio":false},{"filename":"/docs/love.wasm","crunched":0,"start":43743407,"end":48464133,"audio":false},{"filename":"/docs/theme/bg.png","crunched":0,"start":48464133,"end":48471294,"audio":false},{"filename":"/docs/theme/love.css","crunched":0,"start":48471294,"end":48472154,"audio":false},{"filename":"/game/action_display.lua","crunched":0,"start":48472154,"end":48487375,"audio":false},{"filename":"/game/alert.lua","crunched":0,"start":48487375,"end":48491071,"audio":false},{"filename":"/game/combat.lua","crunched":0,"start":48491071,"end":48497305,"audio":false},{"filename":"/game/constants.lua","crunched":0,"start":48497305,"end":48503610,"audio":false},{"filename":"/game/crew_management.lua","crunched":0,"start":48503610,"end":48509558,"audio":false},{"filename":"/game/draw_steps.lua","crunched":0,"start":48509558,"end":48545645,"audio":false},{"filename":"/game/extra_math.lua","crunched":0,"start":48545645,"end":48547949,"audio":false},{"filename":"/game/fishing/core.lua","crunched":0,"start":48547949,"end":48556996,"audio":false},{"filename":"/game/fishing/minigame.lua","crunched":0,"start":48556996,"end":48576737,"audio":false},{"filename":"/game/fishing/runtime.lua","crunched":0,"start":48576737,"end":48582276,"audio":false},{"filename":"/game/fishing.lua","crunched":0,"start":48582276,"end":48582812,"audio":false},{"filename":"/game/fishing_minigame.lua","crunched":0,"start":48582812,"end":48582876,"audio":false},{"filename":"/game/fishing_runtime.lua","crunched":0,"start":48582876,"end":48583051,"audio":false},{"filename":"/game/gamestate.lua","crunched":0,"start":48583051,"end":48583436,"audio":false},{"filename":"/game/gametypes.lua","crunched":0,"start":48583436,"end":48583728,"audio":false},{"filename":"/game/hunger.lua","crunched":0,"start":48583728,"end":48597130,"audio":false},{"filename":"/game/mobile_controls_steps.lua","crunched":0,"start":48597130,"end":48600284,"audio":false},{"filename":"/game/mod_terminal.lua","crunched":0,"start":48600284,"end":48625348,"audio":false},{"filename":"/game/mods.lua","crunched":0,"start":48625348,"end":48631762,"audio":false},{"filename":"/game/morningtext.lua","crunched":0,"start":48631762,"end":48644857,"audio":false},{"filename":"/game/movement_steps.lua","crunched":0,"start":48644857,"end":48658583,"audio":false},{"filename":"/game/ripple_steps.lua","crunched":0,"start":48658583,"end":48663573,"audio":false},{"filename":"/game/scrolling.lua","crunched":0,"start":48663573,"end":48671884,"audio":false},{"filename":"/game/serialize.lua","crunched":0,"start":48671884,"end":48678187,"audio":false},{"filename":"/game/shaders.lua","crunched":0,"start":48678187,"end":48683102,"audio":false},{"filename":"/game/shopkeeper.lua","crunched":0,"start":48683102,"end":48688667,"audio":false},{"filename":"/game/size.lua","crunched":0,"start":48688667,"end":48689214,"audio":false},{"filename":"/game/spawnenemy.lua","crunched":0,"start":48689214,"end":48709025,"audio":false},{"filename":"/game/state.lua","crunched":0,"start":48709025,"end":48714007,"audio":false},{"filename":"/game/storm.lua","crunched":0,"start":48714007,"end":48729694,"audio":false},{"filename":"/game/suit_theme.lua","crunched":0,"start":48729694,"end":48735618,"audio":false},{"filename":"/game/time_utils.lua","crunched":0,"start":48735618,"end":48736762,"audio":false},{"filename":"/game/top.lua","crunched":0,"start":48736762,"end":48745668,"audio":false},{"filename":"/game/update_steps.lua","crunched":0,"start":48745668,"end":48765940,"audio":false},{"filename":"/game/visuals.lua","crunched":0,"start":48765940,"end":48768886,"audio":false},{"filename":"/game/wake_up.lua","crunched":0,"start":48768886,"end":48772027,"audio":false},{"filename":"/game.lua","crunched":0,"start":48772027,"end":48813376,"audio":false},{"filename":"/host.sh","crunched":0,"start":48813376,"end":48819615,"audio":false},{"filename":"/index_weird.html","crunched":0,"start":48819615,"end":48832458,"audio":false},{"filename":"/lowercase.py","crunched":0,"start":48832458,"end":48833368,"audio":false},{"filename":"/main.lua","crunched":0,"start":48833368,"end":48843042,"audio":false},{"filename":"/menu.lua","crunched":0,"start":48843042,"end":48851867,"audio":false},{"filename":"/mods/always_200_fishing_score.lua","crunched":0,"start":48851867,"end":48853566,"audio":false},{"filename":"/mods/first_tick.txt","crunched":0,"start":48853566,"end":48853592,"audio":false},{"filename":"/mods/fishing_100_coins.lua","crunched":0,"start":48853592,"end":48855802,"audio":false},{"filename":"/mods/mod_log.txt","crunched":0,"start":48855802,"end":48868009,"audio":false},{"filename":"/mods/no_dangerous_zones.lua","crunched":0,"start":48868009,"end":48868519,"audio":false},{"filename":"/sand.lua","crunched":0,"start":48868519,"end":48878067,"audio":false},{"filename":"/scripts/divisions.py","crunched":0,"start":48878067,"end":48880195,"audio":false},{"filename":"/scripts/econ_math.lua","crunched":0,"start":48880195,"end":48887562,"audio":false},{"filename":"/scripts/econ_math_output.csv","crunched":0,"start":48887562,"end":48888958,"audio":false},{"filename":"/scripts/hex2love.lua","crunched":0,"start":48888958,"end":48890204,"audio":false},{"filename":"/shop/controller.lua","crunched":0,"start":48890204,"end":48896993,"audio":false},{"filename":"/shop/economy.lua","crunched":0,"start":48896993,"end":48901387,"audio":false},{"filename":"/shop/inventory_utils.lua","crunched":0,"start":48901387,"end":48902063,"audio":false},{"filename":"/shop/port.lua","crunched":0,"start":48902063,"end":48945296,"audio":false},{"filename":"/shop/state.lua","crunched":0,"start":48945296,"end":48946327,"audio":false},{"filename":"/shop/ui/inventory.lua","crunched":0,"start":48946327,"end":48951265,"audio":false},{"filename":"/shop/ui/main.lua","crunched":0,"start":48951265,"end":48964365,"audio":false},{"filename":"/shop/ui/transfer.lua","crunched":0,"start":48964365,"end":48969821,"audio":false},{"filename":"/shop.lua","crunched":0,"start":48969821,"end":48970642,"audio":false},{"filename":"/voyage.love","crunched":0,"start":48970642,"end":58189187,"audio":false}]});

})();
