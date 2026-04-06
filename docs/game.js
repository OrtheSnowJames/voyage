
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
      Module['FS_createPath']('/', 'mods', true, true);
      Module['FS_createPath']('/', 'scripts', true, true);
      Module['FS_createPath']('/', 'shop', true, true);

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
  loadPackage({"package_uuid":"1b320d0c-0225-4a85-8967-b0c01985b02f","remote_package_size":33159547,"files":[{"filename":"/.gitignore","crunched":0,"start":0,"end":85,"audio":false},{"filename":"/.gitmodules","crunched":0,"start":85,"end":157,"audio":false},{"filename":"/NotoSans-VariableFont_wdth,wght.ttf","crunched":0,"start":157,"end":2044705,"audio":false},{"filename":"/README.md","crunched":0,"start":2044705,"end":2046990,"audio":false},{"filename":"/SUIT/.gitignore","crunched":0,"start":2046990,"end":2047006,"audio":false},{"filename":"/SUIT/README.md","crunched":0,"start":2047006,"end":2048894,"audio":false},{"filename":"/SUIT/button.lua","crunched":0,"start":2048894,"end":2049592,"audio":false},{"filename":"/SUIT/checkbox.lua","crunched":0,"start":2049592,"end":2050415,"audio":false},{"filename":"/SUIT/core.lua","crunched":0,"start":2050415,"end":2054944,"audio":false},{"filename":"/SUIT/docs/Makefile","crunched":0,"start":2054944,"end":2062345,"audio":false},{"filename":"/SUIT/docs/_static/demo.gif","crunched":0,"start":2062345,"end":3386699,"audio":false},{"filename":"/SUIT/docs/_static/different-ids.gif","crunched":0,"start":3386699,"end":3686966,"audio":false},{"filename":"/SUIT/docs/_static/hello-world.gif","crunched":0,"start":3686966,"end":3735495,"audio":false},{"filename":"/SUIT/docs/_static/keyboard.gif","crunched":0,"start":3735495,"end":3744788,"audio":false},{"filename":"/SUIT/docs/_static/layout.gif","crunched":0,"start":3744788,"end":3805138,"audio":false},{"filename":"/SUIT/docs/_static/mutable-state.gif","crunched":0,"start":3805138,"end":3884740,"audio":false},{"filename":"/SUIT/docs/_static/options.gif","crunched":0,"start":3884740,"end":3936734,"audio":false},{"filename":"/SUIT/docs/_static/same-ids.gif","crunched":0,"start":3936734,"end":4282656,"audio":false},{"filename":"/SUIT/docs/conf.py","crunched":0,"start":4282656,"end":4291992,"audio":false},{"filename":"/SUIT/docs/core.rst","crunched":0,"start":4291992,"end":4298214,"audio":false},{"filename":"/SUIT/docs/gettingstarted.rst","crunched":0,"start":4298214,"end":4312518,"audio":false},{"filename":"/SUIT/docs/index.rst","crunched":0,"start":4312518,"end":4321283,"audio":false},{"filename":"/SUIT/docs/layout.rst","crunched":0,"start":4321283,"end":4329827,"audio":false},{"filename":"/SUIT/docs/license.rst","crunched":0,"start":4329827,"end":4331127,"audio":false},{"filename":"/SUIT/docs/themes.rst","crunched":0,"start":4331127,"end":4331179,"audio":false},{"filename":"/SUIT/docs/widgets.rst","crunched":0,"start":4331179,"end":4337640,"audio":false},{"filename":"/SUIT/imagebutton.lua","crunched":0,"start":4337640,"end":4339295,"audio":false},{"filename":"/SUIT/init.lua","crunched":0,"start":4339295,"end":4342006,"audio":false},{"filename":"/SUIT/input.lua","crunched":0,"start":4342006,"end":4345739,"audio":false},{"filename":"/SUIT/label.lua","crunched":0,"start":4345739,"end":4346436,"audio":false},{"filename":"/SUIT/layout.lua","crunched":0,"start":4346436,"end":4355147,"audio":false},{"filename":"/SUIT/license.txt","crunched":0,"start":4355147,"end":4356430,"audio":false},{"filename":"/SUIT/slider.lua","crunched":0,"start":4356430,"end":4358038,"audio":false},{"filename":"/SUIT/suit-0.1-1.rockspec","crunched":0,"start":4358038,"end":4358700,"audio":false},{"filename":"/SUIT/theme.lua","crunched":0,"start":4358700,"end":4363296,"audio":false},{"filename":"/assets/Pirates Red Sprite Sheet.png","crunched":0,"start":4363296,"end":4381986,"audio":false},{"filename":"/assets/Pirates Yellow Sprite Sheet.png","crunched":0,"start":4381986,"end":4400628,"audio":false},{"filename":"/assets/boat.png","crunched":0,"start":4400628,"end":4437455,"audio":false},{"filename":"/assets/fish-icon.png","crunched":0,"start":4437455,"end":4438889,"audio":false},{"filename":"/assets/shopkeeper.png","crunched":0,"start":4438889,"end":4439600,"audio":false},{"filename":"/assets/shore.png","crunched":0,"start":4439600,"end":4468200,"audio":false},{"filename":"/build_web.sh","crunched":0,"start":4468200,"end":4472164,"audio":false},{"filename":"/conf.lua","crunched":0,"start":4472164,"end":4474078,"audio":false},{"filename":"/deploy_pages.sh","crunched":0,"start":4474078,"end":4474696,"audio":false},{"filename":"/docs/.nojekyll","crunched":0,"start":4474696,"end":4474696,"audio":false},{"filename":"/docs/game.data","crunched":0,"start":4474696,"end":18507583,"audio":false},{"filename":"/docs/game.js","crunched":0,"start":18507583,"end":18527376,"audio":false},{"filename":"/docs/index.html","crunched":0,"start":18527376,"end":18532748,"audio":false},{"filename":"/docs/index_weird.html","crunched":0,"start":18532748,"end":18541272,"audio":false},{"filename":"/docs/love.js","crunched":0,"start":18541272,"end":18866726,"audio":false},{"filename":"/docs/love.wasm","crunched":0,"start":18866726,"end":23587452,"audio":false},{"filename":"/docs/theme/bg.png","crunched":0,"start":23587452,"end":23594613,"audio":false},{"filename":"/docs/theme/love.css","crunched":0,"start":23594613,"end":23595473,"audio":false},{"filename":"/game/alert.lua","crunched":0,"start":23595473,"end":23596835,"audio":false},{"filename":"/game/combat.lua","crunched":0,"start":23596835,"end":23603069,"audio":false},{"filename":"/game/constants.lua","crunched":0,"start":23603069,"end":23606972,"audio":false},{"filename":"/game/crew_management.lua","crunched":0,"start":23606972,"end":23612655,"audio":false},{"filename":"/game/draw_steps.lua","crunched":0,"start":23612655,"end":23640490,"audio":false},{"filename":"/game/fishing.lua","crunched":0,"start":23640490,"end":23670465,"audio":false},{"filename":"/game/fishing_minigame.lua","crunched":0,"start":23670465,"end":23670529,"audio":false},{"filename":"/game/fishing_runtime.lua","crunched":0,"start":23670529,"end":23670704,"audio":false},{"filename":"/game/gamestate.lua","crunched":0,"start":23670704,"end":23671089,"audio":false},{"filename":"/game/gametypes.lua","crunched":0,"start":23671089,"end":23671348,"audio":false},{"filename":"/game/hunger.lua","crunched":0,"start":23671348,"end":23684901,"audio":false},{"filename":"/game/mobile_controls_steps.lua","crunched":0,"start":23684901,"end":23687561,"audio":false},{"filename":"/game/mods.lua","crunched":0,"start":23687561,"end":23690700,"audio":false},{"filename":"/game/morningtext.lua","crunched":0,"start":23690700,"end":23702359,"audio":false},{"filename":"/game/movement_steps.lua","crunched":0,"start":23702359,"end":23712617,"audio":false},{"filename":"/game/ripple_steps.lua","crunched":0,"start":23712617,"end":23717607,"audio":false},{"filename":"/game/scrolling.lua","crunched":0,"start":23717607,"end":23726039,"audio":false},{"filename":"/game/serialize.lua","crunched":0,"start":23726039,"end":23732342,"audio":false},{"filename":"/game/shaders.lua","crunched":0,"start":23732342,"end":23736912,"audio":false},{"filename":"/game/shopkeeper.lua","crunched":0,"start":23736912,"end":23742477,"audio":false},{"filename":"/game/size.lua","crunched":0,"start":23742477,"end":23743024,"audio":false},{"filename":"/game/spawnenemy.lua","crunched":0,"start":23743024,"end":23759893,"audio":false},{"filename":"/game/state.lua","crunched":0,"start":23759893,"end":23764484,"audio":false},{"filename":"/game/update_steps.lua","crunched":0,"start":23764484,"end":23778555,"audio":false},{"filename":"/game/visuals.lua","crunched":0,"start":23778555,"end":23781487,"audio":false},{"filename":"/game.lua","crunched":0,"start":23781487,"end":23816759,"audio":false},{"filename":"/host.sh","crunched":0,"start":23816759,"end":23822998,"audio":false},{"filename":"/index_weird.html","crunched":0,"start":23822998,"end":23835841,"audio":false},{"filename":"/lowercase.py","crunched":0,"start":23835841,"end":23836751,"audio":false},{"filename":"/main.lua","crunched":0,"start":23836751,"end":23844382,"audio":false},{"filename":"/menu.lua","crunched":0,"start":23844382,"end":23852841,"audio":false},{"filename":"/mods/first_tick.txt","crunched":0,"start":23852841,"end":23852867,"audio":false},{"filename":"/mods/mod_log.txt","crunched":0,"start":23852867,"end":23862968,"audio":false},{"filename":"/sand.lua","crunched":0,"start":23862968,"end":23872516,"audio":false},{"filename":"/scripts/econ_math.lua","crunched":0,"start":23872516,"end":23879883,"audio":false},{"filename":"/scripts/econ_math_output.csv","crunched":0,"start":23879883,"end":23881279,"audio":false},{"filename":"/shop/economy.lua","crunched":0,"start":23881279,"end":23885673,"audio":false},{"filename":"/shop/inventory_utils.lua","crunched":0,"start":23885673,"end":23886349,"audio":false},{"filename":"/shop/port.lua","crunched":0,"start":23886349,"end":23915294,"audio":false},{"filename":"/shop.lua","crunched":0,"start":23915294,"end":23941002,"audio":false},{"filename":"/voyage.love","crunched":0,"start":23941002,"end":33159547,"audio":false}]});

})();
