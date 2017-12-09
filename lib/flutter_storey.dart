library flutter_storey;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:flutter/material.dart';

import 'package:storey/storey.dart';

/// Container for storey store.
///
/// It teardown storey store in two situations:
/// * This widget got unmounted from widget tree.
/// * This widget got replaced by a widget with different store.
@immutable
class StoreContainer extends StatefulWidget {
  /// Creates a StoreContainer with specified storey store and a child widget.
  ///
  /// The child widget will be placed at a tree with the specified store as root
  /// store.
  StoreContainer({
    Key key,
    @required this.store,
    @required this.child,
  }) : super(key: key);

  final Store<dynamic> store;
  final Widget child;

  @override
  _StoreContainerState createState() => new _StoreContainerState();
}

class _StoreContainerState extends State<StoreContainer> {
  @override
  void dispose() {
    widget.store.teardown();
    super.dispose();
  }

  @override
  void didUpdateWidget(StoreContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.store != oldWidget.store) {
      oldWidget.store.teardown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return new StoreProvider(store: widget.store, child: widget.child);
  }
}

/// Provides storey store to all descendant widgets.
///
/// Use [StoreProvider.of] to retrieve the root store or its descendant store.
@immutable
class StoreProvider extends InheritedWidget {
  /// Creates a StoreProvider with specified storey store and a child widget.
  ///
  /// The child widget will be placed at a tree with the specified store as root
  /// store.
  StoreProvider({
    Key key,
    @required this.store,
    @required Widget child,
  }) : super(key: key, child: child);

  final Store<dynamic> store;

  /// Retrieve the root store or its descendant with non empty path.
  static Store<S> of<S>(BuildContext context, {
    Iterable<String> path = const Iterable.empty(),
    TypeMatcher debugTypeMatcher = const TypeMatcher<dynamic>(),
  }) {
    StoreProvider provider = context.inheritFromWidgetOfExactType(StoreProvider);
    Store<dynamic> store = provider.store.find(path: path, debugTypeMatcher: (dynamic state) => debugTypeMatcher.check(state));
    return store as Store<S>;
  }

  @override
  bool updateShouldNotify(StoreProvider oldWidget) => store != oldWidget.store;
}

typedef ViewModel StoreConverter<S, ViewModel>(Store<S> store);

typedef Widget ViewModelWidgetBuilder<ViewModel>(BuildContext context, ViewModel model);

typedef bool _Equator<T>(T a, T b);

bool _equals(dynamic a, dynamic b) {
  return a == b;
}

/// Build widget based on state of store located at [path] of root store.
///
/// StoreConnector establishs connection to store located at [path] of the root
/// store, uses [converter] to convert state to desired [ViewModel], and then
/// use [builder] to produce final widget. The connected store becomes the root
/// store of sub-tree which [builder] resides in.
@immutable
class StoreConnector<S, ViewModel> extends StatelessWidget {
  /// Creates a StoreConnector.
  StoreConnector({
    this.path = const Iterable.empty(),
    this.debugTypeMatcher = const TypeMatcher<dynamic>(),
    @required this.converter,
    bool equals(ViewModel a, ViewModel b) = _equals,
    @required this.builder,
  }) : this.equals = equals;

  /// Location of store related to current root store.
  final Iterable<String> path;

  /// TypeMatcher for debug purpose.
  final debugTypeMatcher;

  /// Convert state of store to [ViewModel].
  final StoreConverter<S, ViewModel> converter;

  /// Only trigger rebuild if new [ViewModel] not equals to last [ViewModel].
  ///
  /// Default to `==`. Set explicitly to null to trigger rebuild on every state
  /// change. `identical` function is another choice.
  final _Equator equals;

  /// Build widget with specified [ViewModel].
  final ViewModelWidgetBuilder<ViewModel> builder;

  @override
  Widget build(BuildContext context) {
    Store<S> store = StoreProvider.of(context,
      path: path,
      debugTypeMatcher: debugTypeMatcher,
    );
    return new StoreProvider(
      store: store,
      child: new _StoreStreamListener(
        store: store,
        converter: converter,
        equals: equals,
        builder: builder,
      ),
    );
  }
}

class _StoreStreamListener<S, ViewModel>  extends StatefulWidget {
  _StoreStreamListener({
    Key key,
    @required this.store,
    @required this.converter,
    this.equals,
    @required this.builder}) : super(key: key);

  final Store<S> store;
  final StoreConverter<S, ViewModel> converter;
  final _Equator equals;
  final ViewModelWidgetBuilder<ViewModel> builder;

  @override
  _StoreStreamListenerState<S, ViewModel> createState() => new _StoreStreamListenerState<S, ViewModel>();
}

class _StoreStreamListenerState<S, ViewModel> extends State<_StoreStreamListener> {
  ViewModel latestModel;
  Stream<ViewModel> stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(_StoreStreamListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.store != oldWidget.store || widget.converter != oldWidget.converter || widget.equals != widget.equals) {
      _initStream();
    }
  }

  void _initStream() {
    stream = widget.store.stream.map((_) => widget.converter(widget.store));
    if (widget.equals != null) {
      stream = stream.where((ViewModel model) => !widget.equals(model, latestModel));
    }
    stream = stream.transform(new StreamTransformer<ViewModel, ViewModel>.fromHandlers(
        handleData: (ViewModel data, EventSink<ViewModel> sink) {
          latestModel = data;
          sink.add(data);
        }
    ));
    latestModel = widget.converter(widget.store);
  }

  @override
  Widget build(BuildContext context) {
    return new StreamBuilder<ViewModel>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<ViewModel> snapshot) {
        return widget.builder(context, latestModel);
      },
    );
  }
}

