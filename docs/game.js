
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
  loadPackage({"package_uuid":"2751e026-ce87-4cd4-b2a6-e66e580c15c9","remote_package_size":90774988,"files":[{"filename":"/.gitignore","crunched":0,"start":0,"end":85,"audio":false},{"filename":"/.gitmodules","crunched":0,"start":85,"end":157,"audio":false},{"filename":"/NotoSans-VariableFont_wdth,wght.ttf","crunched":0,"start":157,"end":2044705,"audio":false},{"filename":"/README.md","crunched":0,"start":2044705,"end":2046990,"audio":false},{"filename":"/SUIT/.gitignore","crunched":0,"start":2046990,"end":2047006,"audio":false},{"filename":"/SUIT/README.md","crunched":0,"start":2047006,"end":2048894,"audio":false},{"filename":"/SUIT/button.lua","crunched":0,"start":2048894,"end":2049592,"audio":false},{"filename":"/SUIT/checkbox.lua","crunched":0,"start":2049592,"end":2050415,"audio":false},{"filename":"/SUIT/core.lua","crunched":0,"start":2050415,"end":2054944,"audio":false},{"filename":"/SUIT/docs/Makefile","crunched":0,"start":2054944,"end":2062345,"audio":false},{"filename":"/SUIT/docs/_static/demo.gif","crunched":0,"start":2062345,"end":3386699,"audio":false},{"filename":"/SUIT/docs/_static/different-ids.gif","crunched":0,"start":3386699,"end":3686966,"audio":false},{"filename":"/SUIT/docs/_static/hello-world.gif","crunched":0,"start":3686966,"end":3735495,"audio":false},{"filename":"/SUIT/docs/_static/keyboard.gif","crunched":0,"start":3735495,"end":3744788,"audio":false},{"filename":"/SUIT/docs/_static/layout.gif","crunched":0,"start":3744788,"end":3805138,"audio":false},{"filename":"/SUIT/docs/_static/mutable-state.gif","crunched":0,"start":3805138,"end":3884740,"audio":false},{"filename":"/SUIT/docs/_static/options.gif","crunched":0,"start":3884740,"end":3936734,"audio":false},{"filename":"/SUIT/docs/_static/same-ids.gif","crunched":0,"start":3936734,"end":4282656,"audio":false},{"filename":"/SUIT/docs/conf.py","crunched":0,"start":4282656,"end":4291992,"audio":false},{"filename":"/SUIT/docs/core.rst","crunched":0,"start":4291992,"end":4298214,"audio":false},{"filename":"/SUIT/docs/gettingstarted.rst","crunched":0,"start":4298214,"end":4312518,"audio":false},{"filename":"/SUIT/docs/index.rst","crunched":0,"start":4312518,"end":4321283,"audio":false},{"filename":"/SUIT/docs/layout.rst","crunched":0,"start":4321283,"end":4329827,"audio":false},{"filename":"/SUIT/docs/license.rst","crunched":0,"start":4329827,"end":4331127,"audio":false},{"filename":"/SUIT/docs/themes.rst","crunched":0,"start":4331127,"end":4331179,"audio":false},{"filename":"/SUIT/docs/widgets.rst","crunched":0,"start":4331179,"end":4337640,"audio":false},{"filename":"/SUIT/imagebutton.lua","crunched":0,"start":4337640,"end":4339295,"audio":false},{"filename":"/SUIT/init.lua","crunched":0,"start":4339295,"end":4342006,"audio":false},{"filename":"/SUIT/input.lua","crunched":0,"start":4342006,"end":4345739,"audio":false},{"filename":"/SUIT/label.lua","crunched":0,"start":4345739,"end":4346436,"audio":false},{"filename":"/SUIT/layout.lua","crunched":0,"start":4346436,"end":4355147,"audio":false},{"filename":"/SUIT/license.txt","crunched":0,"start":4355147,"end":4356430,"audio":false},{"filename":"/SUIT/slider.lua","crunched":0,"start":4356430,"end":4358038,"audio":false},{"filename":"/SUIT/suit-0.1-1.rockspec","crunched":0,"start":4358038,"end":4358700,"audio":false},{"filename":"/SUIT/theme.lua","crunched":0,"start":4358700,"end":4363296,"audio":false},{"filename":"/assets/Pirates Red Sprite Sheet.png","crunched":0,"start":4363296,"end":4381986,"audio":false},{"filename":"/assets/Pirates Yellow Sprite Sheet.png","crunched":0,"start":4381986,"end":4400628,"audio":false},{"filename":"/assets/PixelifySans-SemiBold.ttf","crunched":0,"start":4400628,"end":4451728,"audio":false},{"filename":"/assets/boat.png","crunched":0,"start":4451728,"end":4488555,"audio":false},{"filename":"/assets/fish-icon.png","crunched":0,"start":4488555,"end":4489989,"audio":false},{"filename":"/assets/food.avif","crunched":0,"start":4489989,"end":4493386,"audio":false},{"filename":"/assets/salmon.jpg","crunched":0,"start":4493386,"end":4513918,"audio":false},{"filename":"/assets/shopkeeper.png","crunched":0,"start":4513918,"end":4514629,"audio":false},{"filename":"/assets/shore.png","crunched":0,"start":4514629,"end":4543229,"audio":false},{"filename":"/assets/sleeping.png","crunched":0,"start":4543229,"end":4544209,"audio":false},{"filename":"/assets/wave.png","crunched":0,"start":4544209,"end":4546649,"audio":false},{"filename":"/build_web.sh","crunched":0,"start":4546649,"end":4550613,"audio":false},{"filename":"/conf.lua","crunched":0,"start":4550613,"end":4552527,"audio":false},{"filename":"/deploy_pages.sh","crunched":0,"start":4552527,"end":4553145,"audio":false},{"filename":"/docs/.nojekyll","crunched":0,"start":4553145,"end":4553145,"audio":false},{"filename":"/docs/game.data","crunched":0,"start":4553145,"end":76031426,"audio":false},{"filename":"/docs/game.js","crunched":0,"start":76031426,"end":76053574,"audio":false},{"filename":"/docs/index.html","crunched":0,"start":76053574,"end":76054045,"audio":false},{"filename":"/docs/index_weird.html","crunched":0,"start":76054045,"end":76066888,"audio":false},{"filename":"/docs/love.js","crunched":0,"start":76066888,"end":76392342,"audio":false},{"filename":"/docs/love.wasm","crunched":0,"start":76392342,"end":81113068,"audio":false},{"filename":"/docs/theme/bg.png","crunched":0,"start":81113068,"end":81120229,"audio":false},{"filename":"/docs/theme/love.css","crunched":0,"start":81120229,"end":81121089,"audio":false},{"filename":"/game/action_display.lua","crunched":0,"start":81121089,"end":81136310,"audio":false},{"filename":"/game/alert.lua","crunched":0,"start":81136310,"end":81137672,"audio":false},{"filename":"/game/combat.lua","crunched":0,"start":81137672,"end":81143906,"audio":false},{"filename":"/game/constants.lua","crunched":0,"start":81143906,"end":81150097,"audio":false},{"filename":"/game/crew_management.lua","crunched":0,"start":81150097,"end":81155968,"audio":false},{"filename":"/game/draw_steps.lua","crunched":0,"start":81155968,"end":81188938,"audio":false},{"filename":"/game/fishing/core.lua","crunched":0,"start":81188938,"end":81197985,"audio":false},{"filename":"/game/fishing/minigame.lua","crunched":0,"start":81197985,"end":81217726,"audio":false},{"filename":"/game/fishing/runtime.lua","crunched":0,"start":81217726,"end":81223265,"audio":false},{"filename":"/game/fishing.lua","crunched":0,"start":81223265,"end":81223801,"audio":false},{"filename":"/game/fishing_minigame.lua","crunched":0,"start":81223801,"end":81223865,"audio":false},{"filename":"/game/fishing_runtime.lua","crunched":0,"start":81223865,"end":81224040,"audio":false},{"filename":"/game/gamestate.lua","crunched":0,"start":81224040,"end":81224425,"audio":false},{"filename":"/game/gametypes.lua","crunched":0,"start":81224425,"end":81224684,"audio":false},{"filename":"/game/hunger.lua","crunched":0,"start":81224684,"end":81238011,"audio":false},{"filename":"/game/mobile_controls_steps.lua","crunched":0,"start":81238011,"end":81241165,"audio":false},{"filename":"/game/mod_terminal.lua","crunched":0,"start":81241165,"end":81257648,"audio":false},{"filename":"/game/mods.lua","crunched":0,"start":81257648,"end":81264062,"audio":false},{"filename":"/game/morningtext.lua","crunched":0,"start":81264062,"end":81275817,"audio":false},{"filename":"/game/movement_steps.lua","crunched":0,"start":81275817,"end":81288032,"audio":false},{"filename":"/game/ripple_steps.lua","crunched":0,"start":81288032,"end":81293022,"audio":false},{"filename":"/game/scrolling.lua","crunched":0,"start":81293022,"end":81301454,"audio":false},{"filename":"/game/serialize.lua","crunched":0,"start":81301454,"end":81307757,"audio":false},{"filename":"/game/shaders.lua","crunched":0,"start":81307757,"end":81312327,"audio":false},{"filename":"/game/shopkeeper.lua","crunched":0,"start":81312327,"end":81317892,"audio":false},{"filename":"/game/size.lua","crunched":0,"start":81317892,"end":81318439,"audio":false},{"filename":"/game/spawnenemy.lua","crunched":0,"start":81318439,"end":81337879,"audio":false},{"filename":"/game/state.lua","crunched":0,"start":81337879,"end":81342508,"audio":false},{"filename":"/game/time_utils.lua","crunched":0,"start":81342508,"end":81343652,"audio":false},{"filename":"/game/top.lua","crunched":0,"start":81343652,"end":81352193,"audio":false},{"filename":"/game/update_steps.lua","crunched":0,"start":81352193,"end":81366782,"audio":false},{"filename":"/game/visuals.lua","crunched":0,"start":81366782,"end":81369714,"audio":false},{"filename":"/game.lua","crunched":0,"start":81369714,"end":81404785,"audio":false},{"filename":"/host.sh","crunched":0,"start":81404785,"end":81411024,"audio":false},{"filename":"/index_weird.html","crunched":0,"start":81411024,"end":81423867,"audio":false},{"filename":"/lowercase.py","crunched":0,"start":81423867,"end":81424777,"audio":false},{"filename":"/main.lua","crunched":0,"start":81424777,"end":81434296,"audio":false},{"filename":"/menu.lua","crunched":0,"start":81434296,"end":81442755,"audio":false},{"filename":"/mods/always_200_fishing_score.lua","crunched":0,"start":81442755,"end":81444311,"audio":false},{"filename":"/mods/first_tick.txt","crunched":0,"start":81444311,"end":81444337,"audio":false},{"filename":"/mods/fishing_100_coins.lua","crunched":0,"start":81444337,"end":81446254,"audio":false},{"filename":"/mods/mod_log.txt","crunched":0,"start":81446254,"end":81458461,"audio":false},{"filename":"/sand.lua","crunched":0,"start":81458461,"end":81468009,"audio":false},{"filename":"/scripts/divisions.py","crunched":0,"start":81468009,"end":81470137,"audio":false},{"filename":"/scripts/econ_math.lua","crunched":0,"start":81470137,"end":81477504,"audio":false},{"filename":"/scripts/econ_math_output.csv","crunched":0,"start":81477504,"end":81478900,"audio":false},{"filename":"/scripts/hex2love.lua","crunched":0,"start":81478900,"end":81480152,"audio":false},{"filename":"/shop/controller.lua","crunched":0,"start":81480152,"end":81486917,"audio":false},{"filename":"/shop/economy.lua","crunched":0,"start":81486917,"end":81491311,"audio":false},{"filename":"/shop/inventory_utils.lua","crunched":0,"start":81491311,"end":81491987,"audio":false},{"filename":"/shop/port.lua","crunched":0,"start":81491987,"end":81531097,"audio":false},{"filename":"/shop/state.lua","crunched":0,"start":81531097,"end":81532128,"audio":false},{"filename":"/shop/ui/inventory.lua","crunched":0,"start":81532128,"end":81537066,"audio":false},{"filename":"/shop/ui/main.lua","crunched":0,"start":81537066,"end":81550166,"audio":false},{"filename":"/shop/ui/transfer.lua","crunched":0,"start":81550166,"end":81555622,"audio":false},{"filename":"/shop.lua","crunched":0,"start":81555622,"end":81556443,"audio":false},{"filename":"/voyage.love","crunched":0,"start":81556443,"end":90774988,"audio":false}]});

})();
