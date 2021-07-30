import 'dart:async';
import 'dart:io';
import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '奥运奖牌榜',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      debugShowCheckedModeBanner: false,
      home: MyHomePage(title: '奥运奖牌榜'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class MetalInfo {
  String country = '';
  int gold = 0;
  int silver = 0;
  int bronze = 0;
  int total = 0;
  Image flag;
  bool selected = false;

  MetalInfo(this.country, this.gold, this.silver, this.bronze, this.flag) {
    this.country = country;
    this.gold = gold;
    this.silver = silver;
    this.bronze = bronze;
    this.total = gold + silver + bronze;
    this.flag = flag;
  }
}

class _MyHomePageState extends State<MyHomePage> {
  var refreshKey = GlobalKey<RefreshIndicatorState>();
  String _statusText = '';

  var _jsonData;
  List<MetalInfo> _metalInfo = [];

  int _currentSortColumn = 2;
  bool _isAscending = false;

  @override
  void initState() {
    super.initState();

    _getDataFromServer();
  }

  List<DataRow> _updateMetalData(double displayWidth) {
    List<DataRow> dataRows = [];

    for (MetalInfo eachCountry in _metalInfo) {
      dataRows.add(
          DataRow(
              selected: false,
              onSelectChanged: (selected) {
                setState(() {
                  eachCountry.selected = selected!;
                });
              },
              cells: [
                DataCell(
                  Container (
                    width: displayWidth / 10,
                    child: eachCountry.flag),
                ),
                DataCell(
                  Container (
                    child: Text(
                      eachCountry.country,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                    )),
                ),
                DataCell(
                  Container (
                    width: displayWidth / 10,
                    child: Text(
                      eachCountry.gold.toString(),
                      textAlign: TextAlign.center,
                    )),
                ),
                DataCell(
                  Container (
                    width: displayWidth / 10,
                    child: Text(
                      eachCountry.silver.toString(),
                      textAlign: TextAlign.center,
                    )),
                ),
                DataCell(
                  Container (
                    width: displayWidth / 10,
                    child: Text(
                      eachCountry.bronze.toString(),
                      textAlign: TextAlign.center,
                    )),
                ),
                DataCell(
                  Container (
                    width: displayWidth / 10,
                    child: Text(
                      eachCountry.total.toString(),
                      textAlign: TextAlign.center,
                    )),
                ),
              ]
          )
      );
    }

    return dataRows;
  }

  void _getDataFromServer() async {
    var httpUri = Uri.http('duanwy.com', '/api/olympic/FlutterStudy');
    List<int> rawBytes = [];
    String finalText;

    setState(() {
      _statusText = '正在载入...';
    });

    var httpClient = http.Client();

    try {
      var httpRequest = http.Request('GET', httpUri);
      var httpRet = await httpClient.send(httpRequest).timeout(const Duration(seconds: 60));

      var totalLength = httpRet.contentLength ?? 0;

      httpRet.stream.listen((value) {
        rawBytes.addAll(value);
        setState(() {
          _statusText = '正在载入...' + rawBytes.length.toString() + '/' +
              totalLength.toString();
        });
      })
        ..onError((error) {
          setState(() {
            _statusText = '错误: ' + error.toString();
          });
          httpClient.close();
        })
        ..onDone(() {
          bool isDataInvalid = false;
          finalText = convert.utf8.decode(rawBytes);

          setState(() {
            if (httpRet.statusCode != 200) {
              isDataInvalid = true;
              _statusText = '错误: 网络异常.';
            }

            if (finalText.startsWith('NG')) {
              isDataInvalid = true;
              _statusText = finalText;
            }

            if (!isDataInvalid) {
              _jsonData = convert.jsonDecode(finalText);
              List<MetalInfo> newMetalList = [];

              try {
                for (var eachItem in _jsonData) {
                  String country = eachItem['country'];
                  int gold = eachItem['gold'];
                  int silver = eachItem['silver'];
                  int bronze = eachItem['bronze'];
                  Uint8List rawFlag = convert.base64Decode(eachItem['flag']);

                  newMetalList.add(MetalInfo(country,
                                             gold,
                                             silver,
                                             bronze,
                                             Image.memory(rawFlag)));
                }

                _statusText = '';
                _metalInfo = newMetalList;
              } on Error {
                _statusText = '错误: 数据格式异常.';
              }
            }

            httpClient.close();
          });
        });
    }
    on SocketException {
      setState(() {
        _statusText = '错误: 网络连接失败.';
      });
    }
    on TimeoutException {
      setState(() {
        _statusText = '错误: 连接超时.';
      });
    } on Error catch (ex) {
      setState(() {
        _statusText = '错误: ' + ex.toString();
      });
    }
  }

  Future<Null> pullToRefresh() async {
    refreshKey.currentState?.show(atTop: true);
    _getDataFromServer();

    return null;
  }


  @override
  Widget build(BuildContext context) {
    double displayWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _getDataFromServer,
          ),
        ],
      ),
      body: Center(
        child: Column (
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_statusText.length > 0) Expanded (
              flex: 1,
              child: Column (
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text (
                    _statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle (
                        fontSize: 20
                    ),
                  ),
                ],
              ),
            ),
            if (_metalInfo.isNotEmpty) Expanded (
              flex: 10,
              child: RefreshIndicator (
                  strokeWidth: 4.0,
                  onRefresh: pullToRefresh,
                  child: SingleChildScrollView (
                    child: DataTable (
                    sortAscending: _isAscending,
                    sortColumnIndex: _currentSortColumn,
                    dataRowHeight: 50,
                    horizontalMargin: 15,
                    columnSpacing: 5,
                    showCheckboxColumn: false,
                    columns: [
                      DataColumn(
                        label: Container (
                          width: displayWidth / 10,
                          child: Text(''),
                        )
                      ),
                      DataColumn(
                        label: Container (
                          child: Text(''),
                        )
                      ),
                      DataColumn(
                        label: Container (
                          width: displayWidth / 10,
                          child: Text(
                            '金牌',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        numeric: true,
                          onSort: (int columnIndex, bool asscending) {
                            setState(() {
                              _currentSortColumn = columnIndex;
                              _isAscending = asscending;

                              if (asscending) {
                                _metalInfo.sort((a, b) => a.gold.compareTo(b.gold));
                              } else {
                                _metalInfo.sort((a, b) => b.gold.compareTo(a.gold));
                              }
                            });
                          },
                      ),
                      DataColumn(
                        label: Container (
                          width: displayWidth / 10,
                          child: Text(
                            '银牌',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        numeric: true,
                        onSort: (int columnIndex, bool asscending) {
                          setState(() {
                            _currentSortColumn = columnIndex;
                            _isAscending = asscending;

                            if (asscending) {
                              _metalInfo.sort((a, b) => a.silver.compareTo(b.silver));
                            } else {
                              _metalInfo.sort((a, b) => b.silver.compareTo(a.silver));
                            }
                          });
                        },
                      ),
                      DataColumn(
                        label: Container (
                          width: displayWidth / 10,
                          child: Text(
                            '铜牌',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        numeric: true,
                        onSort: (int columnIndex, bool asscending) {
                          setState(() {
                            _currentSortColumn = columnIndex;
                            _isAscending = asscending;

                            if (asscending) {
                              _metalInfo.sort((a, b) => a.bronze.compareTo(b.bronze));
                            } else {
                              _metalInfo.sort((a, b) => b.bronze.compareTo(a.bronze));
                            }
                          });
                        },
                      ),
                      DataColumn(
                        label: Container (
                          width: displayWidth / 10,
                          child: Text(
                            '总数',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        numeric: true,
                        onSort: (int columnIndex, bool asscending) {
                          setState(() {
                            _currentSortColumn = columnIndex;
                            _isAscending = asscending;

                            if (asscending) {
                              _metalInfo.sort((a, b) => a.total.compareTo(b.total));
                            } else {
                              _metalInfo.sort((a, b) => b.total.compareTo(a.total));
                            }
                          });
                        },
                      ),
                    ],
                    rows: _updateMetalData(displayWidth)
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
