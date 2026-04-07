
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
  loadPackage({"package_uuid":"e42f01cd-fbc3-44d0-b39d-91c7c5b71b58","remote_package_size":71478281,"files":[{"filename":"/.gitignore","crunched":0,"start":0,"end":85,"audio":false},{"filename":"/.gitmodules","crunched":0,"start":85,"end":157,"audio":false},{"filename":"/NotoSans-VariableFont_wdth,wght.ttf","crunched":0,"start":157,"end":2044705,"audio":false},{"filename":"/README.md","crunched":0,"start":2044705,"end":2046990,"audio":false},{"filename":"/SUIT/.gitignore","crunched":0,"start":2046990,"end":2047006,"audio":false},{"filename":"/SUIT/README.md","crunched":0,"start":2047006,"end":2048894,"audio":false},{"filename":"/SUIT/button.lua","crunched":0,"start":2048894,"end":2049592,"audio":false},{"filename":"/SUIT/checkbox.lua","crunched":0,"start":2049592,"end":2050415,"audio":false},{"filename":"/SUIT/core.lua","crunched":0,"start":2050415,"end":2054944,"audio":false},{"filename":"/SUIT/docs/Makefile","crunched":0,"start":2054944,"end":2062345,"audio":false},{"filename":"/SUIT/docs/_static/demo.gif","crunched":0,"start":2062345,"end":3386699,"audio":false},{"filename":"/SUIT/docs/_static/different-ids.gif","crunched":0,"start":3386699,"end":3686966,"audio":false},{"filename":"/SUIT/docs/_static/hello-world.gif","crunched":0,"start":3686966,"end":3735495,"audio":false},{"filename":"/SUIT/docs/_static/keyboard.gif","crunched":0,"start":3735495,"end":3744788,"audio":false},{"filename":"/SUIT/docs/_static/layout.gif","crunched":0,"start":3744788,"end":3805138,"audio":false},{"filename":"/SUIT/docs/_static/mutable-state.gif","crunched":0,"start":3805138,"end":3884740,"audio":false},{"filename":"/SUIT/docs/_static/options.gif","crunched":0,"start":3884740,"end":3936734,"audio":false},{"filename":"/SUIT/docs/_static/same-ids.gif","crunched":0,"start":3936734,"end":4282656,"audio":false},{"filename":"/SUIT/docs/conf.py","crunched":0,"start":4282656,"end":4291992,"audio":false},{"filename":"/SUIT/docs/core.rst","crunched":0,"start":4291992,"end":4298214,"audio":false},{"filename":"/SUIT/docs/gettingstarted.rst","crunched":0,"start":4298214,"end":4312518,"audio":false},{"filename":"/SUIT/docs/index.rst","crunched":0,"start":4312518,"end":4321283,"audio":false},{"filename":"/SUIT/docs/layout.rst","crunched":0,"start":4321283,"end":4329827,"audio":false},{"filename":"/SUIT/docs/license.rst","crunched":0,"start":4329827,"end":4331127,"audio":false},{"filename":"/SUIT/docs/themes.rst","crunched":0,"start":4331127,"end":4331179,"audio":false},{"filename":"/SUIT/docs/widgets.rst","crunched":0,"start":4331179,"end":4337640,"audio":false},{"filename":"/SUIT/imagebutton.lua","crunched":0,"start":4337640,"end":4339295,"audio":false},{"filename":"/SUIT/init.lua","crunched":0,"start":4339295,"end":4342006,"audio":false},{"filename":"/SUIT/input.lua","crunched":0,"start":4342006,"end":4345739,"audio":false},{"filename":"/SUIT/label.lua","crunched":0,"start":4345739,"end":4346436,"audio":false},{"filename":"/SUIT/layout.lua","crunched":0,"start":4346436,"end":4355147,"audio":false},{"filename":"/SUIT/license.txt","crunched":0,"start":4355147,"end":4356430,"audio":false},{"filename":"/SUIT/slider.lua","crunched":0,"start":4356430,"end":4358038,"audio":false},{"filename":"/SUIT/suit-0.1-1.rockspec","crunched":0,"start":4358038,"end":4358700,"audio":false},{"filename":"/SUIT/theme.lua","crunched":0,"start":4358700,"end":4363296,"audio":false},{"filename":"/assets/Pirates Red Sprite Sheet.png","crunched":0,"start":4363296,"end":4381986,"audio":false},{"filename":"/assets/Pirates Yellow Sprite Sheet.png","crunched":0,"start":4381986,"end":4400628,"audio":false},{"filename":"/assets/boat.png","crunched":0,"start":4400628,"end":4437455,"audio":false},{"filename":"/assets/fish-icon.png","crunched":0,"start":4437455,"end":4438889,"audio":false},{"filename":"/assets/shopkeeper.png","crunched":0,"start":4438889,"end":4439600,"audio":false},{"filename":"/assets/shore.png","crunched":0,"start":4439600,"end":4468200,"audio":false},{"filename":"/assets/sleeping.png","crunched":0,"start":4468200,"end":4469180,"audio":false},{"filename":"/build_web.sh","crunched":0,"start":4469180,"end":4473144,"audio":false},{"filename":"/conf.lua","crunched":0,"start":4473144,"end":4475058,"audio":false},{"filename":"/deploy_pages.sh","crunched":0,"start":4475058,"end":4475676,"audio":false},{"filename":"/docs/.nojekyll","crunched":0,"start":4475676,"end":4475676,"audio":false},{"filename":"/docs/game.data","crunched":0,"start":4475676,"end":56762175,"audio":false},{"filename":"/docs/game.js","crunched":0,"start":56762175,"end":56782842,"audio":false},{"filename":"/docs/index.html","crunched":0,"start":56782842,"end":56783313,"audio":false},{"filename":"/docs/index_weird.html","crunched":0,"start":56783313,"end":56796156,"audio":false},{"filename":"/docs/love.js","crunched":0,"start":56796156,"end":57121610,"audio":false},{"filename":"/docs/love.wasm","crunched":0,"start":57121610,"end":61842336,"audio":false},{"filename":"/docs/theme/bg.png","crunched":0,"start":61842336,"end":61849497,"audio":false},{"filename":"/docs/theme/love.css","crunched":0,"start":61849497,"end":61850357,"audio":false},{"filename":"/game/action_display.lua","crunched":0,"start":61850357,"end":61865578,"audio":false},{"filename":"/game/alert.lua","crunched":0,"start":61865578,"end":61866940,"audio":false},{"filename":"/game/combat.lua","crunched":0,"start":61866940,"end":61873174,"audio":false},{"filename":"/game/constants.lua","crunched":0,"start":61873174,"end":61879365,"audio":false},{"filename":"/game/crew_management.lua","crunched":0,"start":61879365,"end":61885048,"audio":false},{"filename":"/game/draw_steps.lua","crunched":0,"start":61885048,"end":61915833,"audio":false},{"filename":"/game/fishing/core.lua","crunched":0,"start":61915833,"end":61924880,"audio":false},{"filename":"/game/fishing/minigame.lua","crunched":0,"start":61924880,"end":61944621,"audio":false},{"filename":"/game/fishing/runtime.lua","crunched":0,"start":61944621,"end":61950160,"audio":false},{"filename":"/game/fishing.lua","crunched":0,"start":61950160,"end":61950696,"audio":false},{"filename":"/game/fishing_minigame.lua","crunched":0,"start":61950696,"end":61950760,"audio":false},{"filename":"/game/fishing_runtime.lua","crunched":0,"start":61950760,"end":61950935,"audio":false},{"filename":"/game/gamestate.lua","crunched":0,"start":61950935,"end":61951320,"audio":false},{"filename":"/game/gametypes.lua","crunched":0,"start":61951320,"end":61951579,"audio":false},{"filename":"/game/hunger.lua","crunched":0,"start":61951579,"end":61965133,"audio":false},{"filename":"/game/mobile_controls_steps.lua","crunched":0,"start":61965133,"end":61968287,"audio":false},{"filename":"/game/mod_terminal.lua","crunched":0,"start":61968287,"end":61984433,"audio":false},{"filename":"/game/mods.lua","crunched":0,"start":61984433,"end":61988725,"audio":false},{"filename":"/game/morningtext.lua","crunched":0,"start":61988725,"end":62000480,"audio":false},{"filename":"/game/movement_steps.lua","crunched":0,"start":62000480,"end":62010738,"audio":false},{"filename":"/game/ripple_steps.lua","crunched":0,"start":62010738,"end":62015728,"audio":false},{"filename":"/game/scrolling.lua","crunched":0,"start":62015728,"end":62024160,"audio":false},{"filename":"/game/serialize.lua","crunched":0,"start":62024160,"end":62030463,"audio":false},{"filename":"/game/shaders.lua","crunched":0,"start":62030463,"end":62035033,"audio":false},{"filename":"/game/shopkeeper.lua","crunched":0,"start":62035033,"end":62040598,"audio":false},{"filename":"/game/size.lua","crunched":0,"start":62040598,"end":62041145,"audio":false},{"filename":"/game/spawnenemy.lua","crunched":0,"start":62041145,"end":62058015,"audio":false},{"filename":"/game/state.lua","crunched":0,"start":62058015,"end":62062644,"audio":false},{"filename":"/game/time_utils.lua","crunched":0,"start":62062644,"end":62063788,"audio":false},{"filename":"/game/update_steps.lua","crunched":0,"start":62063788,"end":62078377,"audio":false},{"filename":"/game/visuals.lua","crunched":0,"start":62078377,"end":62081309,"audio":false},{"filename":"/game.lua","crunched":0,"start":62081309,"end":62116380,"audio":false},{"filename":"/host.sh","crunched":0,"start":62116380,"end":62122619,"audio":false},{"filename":"/index_weird.html","crunched":0,"start":62122619,"end":62135462,"audio":false},{"filename":"/lowercase.py","crunched":0,"start":62135462,"end":62136372,"audio":false},{"filename":"/main.lua","crunched":0,"start":62136372,"end":62145891,"audio":false},{"filename":"/menu.lua","crunched":0,"start":62145891,"end":62154350,"audio":false},{"filename":"/mods/first_tick.txt","crunched":0,"start":62154350,"end":62154376,"audio":false},{"filename":"/mods/mod_log.txt","crunched":0,"start":62154376,"end":62166583,"audio":false},{"filename":"/sand.lua","crunched":0,"start":62166583,"end":62176131,"audio":false},{"filename":"/scripts/always_200_fishing_score.lua","crunched":0,"start":62176131,"end":62177687,"audio":false},{"filename":"/scripts/econ_math.lua","crunched":0,"start":62177687,"end":62185054,"audio":false},{"filename":"/scripts/econ_math_output.csv","crunched":0,"start":62185054,"end":62186450,"audio":false},{"filename":"/scripts/hex2love.lua","crunched":0,"start":62186450,"end":62187702,"audio":false},{"filename":"/shop/controller.lua","crunched":0,"start":62187702,"end":62194286,"audio":false},{"filename":"/shop/economy.lua","crunched":0,"start":62194286,"end":62198680,"audio":false},{"filename":"/shop/inventory_utils.lua","crunched":0,"start":62198680,"end":62199356,"audio":false},{"filename":"/shop/port.lua","crunched":0,"start":62199356,"end":62234780,"audio":false},{"filename":"/shop/state.lua","crunched":0,"start":62234780,"end":62235811,"audio":false},{"filename":"/shop/ui/inventory.lua","crunched":0,"start":62235811,"end":62240644,"audio":false},{"filename":"/shop/ui/main.lua","crunched":0,"start":62240644,"end":62253577,"audio":false},{"filename":"/shop/ui/transfer.lua","crunched":0,"start":62253577,"end":62258915,"audio":false},{"filename":"/shop.lua","crunched":0,"start":62258915,"end":62259736,"audio":false},{"filename":"/voyage.love","crunched":0,"start":62259736,"end":71478281,"audio":false}]});

})();
