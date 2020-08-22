import 'package:flutter/material.dart';
import 'package:komodo_dex/blocs/authenticate_bloc.dart';
import 'package:komodo_dex/blocs/settings_bloc.dart';
import 'package:komodo_dex/blocs/wallet_bloc.dart';
import 'package:komodo_dex/localizations.dart';
import 'package:komodo_dex/screens/authentification/lock_screen.dart';
import 'package:komodo_dex/screens/authentification/pin_page.dart';
import 'package:komodo_dex/screens/authentification/unlock_wallet_page.dart';
import 'package:komodo_dex/utils/encryption_tool.dart';
import 'package:komodo_dex/widgets/shared_preferences_builder.dart';

class CamoPinSetupPage extends StatefulWidget {
  @override
  _CamoPinSetupPageState createState() => _CamoPinSetupPageState();
}

class _CamoPinSetupPageState extends State<CamoPinSetupPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
        initialData: authBloc.isCamoActive,
        stream: authBloc.outIsCamoActive,
        builder: (context, AsyncSnapshot<bool> snapshot) {
          if (!snapshot.hasData) return Container();
          if (snapshot.data) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.popUntil(context, ModalRoute.withName('/'));
            });
            return Container();
          }

          return LockScreen(
            context: context,
            child: Scaffold(
              backgroundColor: Theme.of(context).backgroundColor,
              appBar: AppBar(
                // TODO(yurii): localization
                title: const Text('Camouflage PIN'),
              ),
              body: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildSwitcher(),
                      _buildDescription(),
                      _buildPinSetup(),
                      _buildPercentSetup(),
                      _buildWarnings(),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget _buildPercentSetup() {
    return StreamBuilder<int>(
      initialData: settingsBloc.camoPercent,
      stream: settingsBloc.outCamoPercent,
      builder: (context, AsyncSnapshot<int> camoPercent) {
        if (!camoPercent.hasData) return Container();

        return StreamBuilder<bool>(
            initialData: settingsBloc.isCamoEnabled,
            stream: settingsBloc.outCamoEnabled,
            builder: (context, AsyncSnapshot<bool> camoEnabled) {
              if (!camoEnabled.hasData) return Container();

              return Opacity(
                opacity: camoEnabled.data ? 1 : 0.5,
                child: Card(
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            const Expanded(
                                child: Text(
                              // TODO(yurii): localization
                              'Fake balance amount:',
                              style: TextStyle(fontSize: 18),
                            )),
                            Text(
                              '${camoPercent.data}%',
                              style: TextStyle(
                                color: Theme.of(context).accentColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          valueIndicatorTextStyle: TextStyle(
                              color: Theme.of(context).backgroundColor),
                        ),
                        child: Slider(
                            activeColor: Theme.of(context).accentColor,
                            divisions: 50,
                            label: camoPercent.data.toString(),
                            min: 1,
                            max: 50,
                            value: camoPercent.data.toDouble(),
                            onChanged: camoEnabled.data
                                ? (double value) {
                                    settingsBloc.setCamoPercent(value.round());
                                  }
                                : null),
                      ),
                    ],
                  ),
                ),
              );
            });
      },
    );
  }

  Widget _buildWarnings() {
    return StreamBuilder<bool>(
        initialData: settingsBloc.isCamoEnabled,
        stream: settingsBloc.outCamoEnabled,
        builder: (context, camoEnabled) {
          if (camoEnabled.data != true) return Container();

          return FutureBuilder<String>(
              future: EncryptionTool().read('pin'),
              builder: (context, AsyncSnapshot<String> normalPin) {
                if (!normalPin.hasData) return Container();

                return SharedPreferencesBuilder<dynamic>(
                    pref: 'switch_pin',
                    builder: (BuildContext context,
                        AsyncSnapshot<dynamic> normalPinEnabled) {
                      if (!normalPinEnabled.hasData) return Container();

                      if (normalPinEnabled.data) {
                        return FutureBuilder<String>(
                            future: EncryptionTool().read('camoPin'),
                            builder: (context, AsyncSnapshot<String> camoPin) {
                              if (!camoPin.hasData) return Container();
                              if (camoPin.data != normalPin.data)
                                return Container();

                              return Container(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  // TODO(yurii): localization
                                  'Your general PIN and Camouflage PIN are the same.\n'
                                  'Camouflage mode will not be available.'
                                  '\nPlease change Camouflage PIN.',
                                  style: TextStyle(
                                    color: Theme.of(context).errorColor,
                                    height: 1.2,
                                  ),
                                ),
                              );
                            });
                      } else {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            // TODO(yurii): localization
                            'General PIN protection is not active.\n'
                            'Camouflage mode will not be available.'
                            '\nPlease activate PIN protection.',
                            style: TextStyle(
                              color: Theme.of(context).errorColor,
                              height: 1.2,
                            ),
                          ),
                        );
                      }
                    });
              });
        });
  }

  Widget _buildPinSetup() {
    return FutureBuilder<String>(
        future: EncryptionTool().read('camoPin'),
        builder: (context, AsyncSnapshot<String> camoPinSnapshot) {
          final String camoPin =
              camoPinSnapshot.hasData ? camoPinSnapshot.data : null;

          return StreamBuilder<bool>(
              initialData: settingsBloc.isCamoEnabled,
              stream: settingsBloc.outCamoEnabled,
              builder: (context, AsyncSnapshot<bool> camoEnabledSnapshot) {
                if (!camoEnabledSnapshot.hasData) return Container();

                final bool isEnabled = camoEnabledSnapshot.data;
                return Opacity(
                  opacity: isEnabled ? 1 : 0.5,
                  child: Card(
                    child: InkWell(
                      onTap: isEnabled ? () => _startPinSetup() : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: camoPin == null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          // TODO(yurii): localization
                                          'Camouflage PIN not found',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: isEnabled
                                                ? Colors.pinkAccent
                                                : null,
                                          ),
                                        ),
                                        Text(
                                          // TODO(yurii): localization
                                          'Create Camouflage PIN',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).disabledColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        const Text(
                                          // TODO(yurii): localization
                                          'Camouflage PIN saved',
                                          style: TextStyle(
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          // TODO(yurii): localization
                                          'Change Camouflage PIN',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).disabledColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            Icon(Icons.dialpad),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              });
        });
  }

  void _startPinSetup() {
    Navigator.push<dynamic>(
        context,
        MaterialPageRoute<dynamic>(
            builder: (BuildContext context) => UnlockWalletPage(
                  textButton: AppLocalizations.of(context).unlock,
                  wallet: walletBloc.currentWallet,
                  isSignWithSeedIsEnabled: false,
                  onSuccess: (_, String password) {
                    Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute<dynamic>(
                            builder: (BuildContext context) => PinPage(
                                // TODO(yurii): localization
                                title: 'Camouflage PIN Setup',
                                subTitle: 'Enter new Camouflage PIN',
                                pinStatus: PinStatus.CREATE_CAMO_PIN,
                                password: password)));
                  },
                )));
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 24,
      ),
      child: Text(
          // TODO(yurii): localization
          'If You\'ll unlock the app with the Camouflage PIN, a fake'
          ' LOW balance will be shown'
          ' and the Camouflage PIN config option will'
          ' NOT be visible in the settings',
          style: TextStyle(
            height: 1.3,
            color: Theme.of(context).disabledColor,
          )),
    );
  }

  Widget _buildSwitcher() {
    return StreamBuilder<bool>(
        initialData: settingsBloc.isCamoEnabled,
        stream: settingsBloc.outCamoEnabled,
        builder: (context, AsyncSnapshot<bool> snapshot) {
          if (!snapshot.hasData) return Container();

          final bool isEnabled = snapshot.data;
          return Card(
            child: InkWell(
              onTap: () {
                _switchEnabled(!isEnabled);
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  top: 8,
                  bottom: 8,
                  right: 8,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        isEnabled ? 'On' : 'Off',
                        style: const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      onChanged: (bool value) {
                        _switchEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Future<void> _switchEnabled(bool val) async {
    settingsBloc.setCamoEnabled(val);

    final String savedPin = await EncryptionTool().read('camoPin');
    if (val && savedPin == null) _startPinSetup();
  }
}
