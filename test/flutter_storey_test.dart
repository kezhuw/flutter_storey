import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide TypeMatcher;

import 'package:storey/storey.dart';
import 'package:flutter_storey/flutter_storey.dart';

class FooState {
  FooState([this.foo = 'foo']);

  dynamic foo;
}

class FooValueAction extends Action {
  const FooValueAction(this.foo);

  final dynamic foo;
}

FooState _handleFooValueAction(FooState state, FooValueAction action) {
  return state..foo = action.foo;
}

Reducer<FooState> fooReducer = new ProxyTypedReducer<FooState, FooValueAction>(_handleFooValueAction);


class BarState {
  BarState([this.bar = 'bar']);

  dynamic bar;
}

class BarModel {
  const BarModel(this.bar);

  final dynamic bar;

  @override
  bool operator ==(dynamic other) {
    return other is BarModel && bar == other.bar;
  }

  @override
  int get hashCode => hashValues(runtimeType, bar);

  static BarModel fromStore(Store<BarState> store) {
    return new BarModel(store.state.bar);
  }
}

class BarValueAction extends Action {
  const BarValueAction(this.value);

  final dynamic value;
}

BarState _handleBarValueAction(BarState state, BarValueAction action) {
  return state..bar = action.value;
}

Reducer<BarState> barReducer = new ProxyTypedReducer<BarState, BarValueAction>(_handleBarValueAction);


class FoobarState {
  FoobarState([this.foobar = 'foobar']);

  dynamic foobar;
}

class FoobarValueAction extends Action {
  const FoobarValueAction(this.foobar);

  final dynamic foobar;
}

FoobarState _handleFoobarValueAction(FoobarState state, FoobarValueAction action) {
  return state..foobar = action.foobar;
}

Reducer<FoobarState> foobarReducer = new ProxyTypedReducer<FoobarState, FoobarValueAction>(_handleFoobarValueAction);


void main() {
  group('StoreContainer', () {
    Store<FooState> store;

    setUp(() {
      store  = new Store<FooState>(
        initialState: new FooState(),
        reducer: fooReducer,
      );
    });

    Widget buildWidget({
      Store<dynamic> store,
      Widget child: const SizedBox(),
    }) {
      return new StoreContainer(
        store: store,
        child: child,
      );
    }

    testWidgets('Progagate store to child widget', (WidgetTester tester) async {
      Store<dynamic> actualStore;

      await tester.pumpWidget(buildWidget(
        store: store,
        child: new Builder(
            builder: (BuildContext context) {
              actualStore = StoreProvider.of(context);
              return const SizedBox();
            }
        ),
      ));

      expect(actualStore, store);
    });

    testWidgets('Teardown if unmounted from widget tree', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(store: store));

      await tester.pumpWidget(const SizedBox());

      expect(store.stream, emitsDone);
    });

    testWidgets('Teardown if replaced by a widget with different store', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(store: store));

      Store<FooState> anotherStore = new Store<FooState>(
        initialState: new FooState(),
        reducer: fooReducer,
      );
      await tester.pumpWidget(buildWidget(store: anotherStore));

      expect(store.stream, emitsDone);
    });
  });

  group('StoreProvider', () {
    Store<BarState> barStore;
    Store<FooState> fooStore;

    setUp(() {
      barStore  = new Store<BarState>(
        initialState: new BarState(),
        reducer: barReducer,
      );

      fooStore  = new Store<FooState>(
        initialState: new FooState(),
        reducer: fooReducer,
        children: <ValueKey<String>, Store<dynamic>>{
          const ValueKey<String>('bar'): barStore,
        },
      );
    });

    Widget buildWidget({
      Store<dynamic> store,
      Widget child: const SizedBox(),
    }) {
      return new StoreProvider(
        store: store,
        child: child,
      );
    }

    testWidgets('Propagate store to child widget', (WidgetTester tester) async {
      Store<dynamic> actualStore;

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        child: new Builder(
            builder: (BuildContext context) {
              actualStore = StoreProvider.of(context);
              return const SizedBox();
            }
        ),
      ));

      expect(actualStore, fooStore);
    });

    testWidgets('Retrieve store using path', (WidgetTester tester) async {
      Store<dynamic> actualStore;

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        child: new Builder(
            builder: (BuildContext context) {
              actualStore = StoreProvider.of(context, path: [const ValueKey<String>('bar')]);
              return const SizedBox();
            }
        ),
      ));

      expect(actualStore, barStore);
    });

    testWidgets('Trigger rebuild if store replaced', (WidgetTester tester) async {
      Store<dynamic> actualStore;

      Widget child = new Builder(
        builder: (BuildContext context) {
          actualStore = StoreProvider.of(context);
          return const SizedBox();
        },
      );

      await tester.pumpWidget(buildWidget(store: fooStore, child: child));
      await tester.pumpWidget(buildWidget(store: barStore, child: child));

      expect(actualStore, barStore);
    });
  });

  group('StoreConnector', () {
    Store<BarState> barStore;
    Store<FooState> fooStore;
    Store<FoobarState> foobarStore;

    const int kEqualsDefault = 0;
    const int kEqualsNull = 1;
    const int kEqualsIdentical = 2;

    setUp(() {
      foobarStore = new Store<FoobarState>(
        initialState: new FoobarState(),
        reducer: foobarReducer,
      );

      barStore  = new Store<BarState>(
        initialState: new BarState(),
        reducer: barReducer,
        children: {
          const ValueKey<String>('foobar'): foobarStore,
        },
      );

      fooStore  = new Store<FooState>(
        initialState: new FooState(),
        reducer: fooReducer,
        children: <ValueKey<String>, Store<dynamic>>{
          const ValueKey<String>('bar'): barStore,
        },
      );
    });

    Widget buildWidget({
      Store<dynamic> store,
      Iterable<dynamic> path = const Iterable.empty(),
      int equals = 0,
      ViewModelWidgetBuilder<BarModel> builder,
    }) {
      Widget connector;
      switch (equals) {
        case kEqualsDefault:
          connector = new StoreConnector(
            path: path,
            converter: BarModel.fromStore,
            builder: builder,
          );
          break;
        case kEqualsNull:
          connector = new StoreConnector(
            path: path,
            converter: BarModel.fromStore,
            builder: builder,
            equals: null,
          );
          break;
        case kEqualsIdentical:
          connector = new StoreConnector(
            path: path,
            converter: BarModel.fromStore,
            builder: builder,
            equals: identical,
          );
          break;
      }
      return new StoreProvider(
        store: store,
        child: connector,
      );
    }

    testWidgets('Builder\'s root store is the store located at path', (WidgetTester tester) async {
      Store<dynamic> actualStore;

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        path: [const ValueKey<String>('bar')],
        builder: (BuildContext context, BarModel model) {
          actualStore = StoreProvider.of(context);
          return const SizedBox();
        },
      ));

      expect(actualStore, barStore);
    });

    testWidgets('Rebuild if current model is not equals to last model', (WidgetTester tester) async {
      List<Store<dynamic>> stores = [];

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        path: [const ValueKey<String>('bar')],
        builder: (BuildContext context, BarModel model) {
          stores.add(StoreProvider.of(context));
          return const SizedBox();
        },
      ));

      barStore.dispatch(const BarValueAction('xxx'));
      expect(barStore.state.bar, 'xxx');

      await tester.pumpAndSettle();
      expect(stores, [barStore, barStore]);
    });

    testWidgets('No rebuild if current model is equals to last model', (WidgetTester tester) async {
      List<Store<dynamic>> stores = [];

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        path: [const ValueKey<String>('bar')],
        builder: (BuildContext context, BarModel model) {
          stores.add(StoreProvider.of(context));
          return const SizedBox();
        },
      ));

      barStore.dispatch(const BarValueAction('bar'));
      expect(barStore.state.bar, 'bar');

      await tester.pumpAndSettle();
      expect(stores, [barStore]);
    });

    testWidgets('Always rebuild when state changed if equals is null', (WidgetTester tester) async {
      List<Store<dynamic>> stores = [];

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        path: [const ValueKey<String>('bar')],
        equals: kEqualsNull,
        builder: (BuildContext context, BarModel model) {
          stores.add(StoreProvider.of(context));
          return const SizedBox();
        },
      ));

      barStore.dispatch(const BarValueAction('bar'));
      expect(barStore.state.bar, 'bar');

      await tester.pumpAndSettle();
      expect(stores, [barStore, barStore]);
    });

    testWidgets('No rebuild if ancestor store\'s state changed', (WidgetTester tester) async {
      List<Store<dynamic>> stores = [];

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        path: [const ValueKey<String>('bar')],
        equals: kEqualsNull,
        builder: (BuildContext context, BarModel model) {
          stores.add(StoreProvider.of(context));
          return const SizedBox();
        },
      ));

      fooStore.dispatch(const FooValueAction('xxx'));
      expect(fooStore.state.foo, 'xxx');

      await tester.pumpAndSettle();
      expect(stores, [barStore]);
    });

    testWidgets('Rebuild if descendant store\'s state changed', (WidgetTester tester) async {
      List<Store<dynamic>> stores = [];

      await tester.pumpWidget(buildWidget(
        store: fooStore,
        path: [const ValueKey<String>('bar')],
        equals: kEqualsNull,
        builder: (BuildContext context, BarModel model) {
          stores.add(StoreProvider.of(context));
          return const SizedBox();
        },
      ));

      foobarStore.dispatch(const FoobarValueAction('xxx'));
      expect(foobarStore.state.foobar, 'xxx');

      await tester.pumpAndSettle();
      expect(stores, [barStore, barStore]);
    });
  });
}