library flutter_storey;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:flutter/material.dart';

import 'package:storey/storey.dart';

@immutable
class StoreContainer extends StatefulWidget {
  StoreContainer({Key key, this.store});

  final Store<dynamic> store;

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
    return new StoreProvider(store: widget.store);
  }
}

@immutable
class StoreProvider extends InheritedWidget {
  StoreProvider({Key key, Widget child, this.store}) : super(key: key, child: child);

  final Store<dynamic> store;

  static Store<S> of<S>(BuildContext context, {
    Iterable<dynamic> path = const Iterable.empty(),
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

@immutable
class StoreConnector<S, ViewModel> extends StatelessWidget {
  StoreConnector({
    this.converter,
    this.builder,
    this.path = const Iterable.empty(),
    this.debugTypeMatcher = const TypeMatcher<dynamic>(),
    bool equals(ViewModel a, ViewModel b) = _equals,
  }) : this.equals = equals;

  final StoreConverter<S, ViewModel> converter;
  final ViewModelWidgetBuilder<ViewModel> builder;
  final Iterable<dynamic> path;
  final debugTypeMatcher;
  final _Equator equals;

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
  _StoreStreamListener({Key key, this.store, this.converter, this.equals, this.builder}) : super(key: key);

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

