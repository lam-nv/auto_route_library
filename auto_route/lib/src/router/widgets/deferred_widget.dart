import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Signature for a function that returns a void future
/// Used in [DeferredWidget] to load deferred libraries
typedef LibraryLoader = Future<void> Function();

/// Signature for a function that returns a widget
/// Used in [DeferredWidget] to build the lazy-loaded library
typedef DeferredWidgetBuilder = Widget Function();

/// Wraps the child inside a deferred module loader.
///
/// The child is created and a single instance of the Widget is maintained in
/// state as long as closure to create widget stays the same.
class DeferredWidget extends StatefulWidget {
  /// default constructor
  const DeferredWidget(
    this.libraryLoader,
    this.createWidget, {
    super.key,
    this.placeholder,
  });

  /// Triggers the deferred library loading process
  final LibraryLoader libraryLoader;

  /// Creates the actual widget after it's loaded
  final DeferredWidgetBuilder createWidget;

  /// The widget is displayed until [libraryLoader] is done loading
  final Widget? placeholder;
  static final Map<LibraryLoader, Future<void>> _moduleLoaders = {};
  static final Set<LibraryLoader> _loadedModules = {};

  static Future<void> _preload(LibraryLoader loader) async {
    if (!_moduleLoaders.containsKey(loader)) {
      try {
        final future = loader();
        _moduleLoaders[loader] = future;

        await future;
        // print('Loaded module: $loader');

        _loadedModules.add(loader);
      } catch (exception) {
        // print('Failed to load module: $loader with error: $exception');
        rethrow;
      }
    }
    return _moduleLoaders[loader]!;
  }

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  _DeferredWidgetState();

  Widget? _loadedChild;
  DeferredWidgetBuilder? _loadedCreator;

  @override
  void initState() {
    /// If module was already loaded immediately create widget instead of
    /// waiting for future or zone turn.
    if (DeferredWidget._loadedModules.contains(widget.libraryLoader)) {
      _onLibraryLoaded();
    } else {
      var preload = DeferredWidget._preload(widget.libraryLoader);
      preload.then(
        (dynamic _) => _onLibraryLoaded(),
        onError: (dynamic error) {
          print('Error loading deferred module: $error');
          DeferredLoadNotification(error).dispatch(context);
        },
      );
    }
    super.initState();
  }

  void _onLibraryLoaded() {
    setState(() {
      _loadedCreator = widget.createWidget;
      _loadedChild = _loadedCreator!();
    });
  }

  @override
  Widget build(BuildContext context) {
    /// If closure to create widget changed, create new instance, otherwise
    /// treat as const Widget.
    if (_loadedCreator != widget.createWidget && _loadedCreator != null) {
      _loadedCreator = widget.createWidget;
      _loadedChild = _loadedCreator!();
    }

    final placeHolder =
        AutoRouterDelegate.of(context).placeholder?.call(context) ??
            const DeferredLoadingPlaceholder();
    return _loadedChild ?? placeHolder;
  }
}

/// Displays a progress indicator when the widget is a deferred component
/// and is currently being installed.
class DeferredLoadingPlaceholder extends StatelessWidget {
  /// default constructor
  const DeferredLoadingPlaceholder({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// A notification that is dispatched when a deferred module is loaded
class DeferredLoadNotification extends Notification {
  /// The error that occurred during the loading of the deferred module
  final DeferredLoadException error;

  /// default constructor
  DeferredLoadNotification(
    this.error,
  );
}
