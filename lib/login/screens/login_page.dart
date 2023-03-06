import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:komodo_dex/login/bloc/login_bloc.dart';
import 'package:komodo_dex/widgets/pin/pin_input.dart';

import '../../generic_blocs/authenticate_bloc.dart';
import '../../generic_blocs/dialog_bloc.dart';
import '../../localizations.dart';
import '../../widgets/page_transition.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    Key? key,
    // this.pinStatus,
    // this.password,
    // this.onSuccess,
    // this.code,
  }) : super(key: key);

  // final String? code;
  // final String? password;
  // final VoidCallback? onSuccess;

  static const String routeName = '/login';

  static MaterialPageRoute<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const LoginPage(),
    );
  }

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();

    _loginBloc = BlocProvider.of<LoginBloc>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // if (_loginBloc.pinStatus == PinStatus.NORMAL_PIN) {
      dialogBloc.closeDialog(context);
      // }
    });
  }

  // Clear bloc persistence when navigating away from this page.
  @override
  void dispose() {
    _loginBloc.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loginBloc = BlocProvider.of<LoginBloc>(context, listen: true);

    final isBlocLoading = _loginBloc.state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isBlocLoading
              ? AppLocalizations.of(context)!.loading
              : AppLocalizations.of(context)!.enterPinCode,
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: BlocListener<LoginBloc, LoginStateAbstract>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state is LoginStatePinSubmittedFailure) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(AppLocalizations.of(context)!.errorTryAgain),
            //   ),
            // );
          }

          if (state is LoginStatePinSubmittedSuccess) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(AppLocalizations.of(context)!.success),
            //   ),
            // );
            // Navigator.of(context)
            //     .pushNamedAndRemoveUntil('/', (route) => false);
          }
        },
        child:
            // _loginBloc.state.isLoading
            //     ? _buildLoading()
            //     :
            Center(
          child: PinInput(
            errorState: _loginBloc.state.isError,
            errorMessage: _loginBloc.state.error,
            obscureText: true,
            length: 6,
            readOnly: isBlocLoading,
            value: context.watch<LoginBloc>().state.pin.value,
            onChanged: (String pin) => _loginBloc.add(
              LoginPinInputChanged(pin),
            ),
            onPinComplete: (String pin) => _loginBloc.add(
              LoginPinSubmitted(pin),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(AppLocalizations.of(context)!.configureWallet)
        ],
      ),
    );
  }
}
