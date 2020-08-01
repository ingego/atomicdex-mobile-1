import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:komodo_dex/blocs/coins_bloc.dart';
import 'package:komodo_dex/blocs/dialog_bloc.dart';
import 'package:komodo_dex/model/addressbook_provider.dart';
import 'package:komodo_dex/model/coin.dart';
import 'package:komodo_dex/screens/addressbook/contact_edit_field.dart';
import 'package:komodo_dex/widgets/confirmation_dialog.dart';
import 'package:komodo_dex/widgets/small_button.dart';
import 'package:provider/provider.dart';

class ContactEdit extends StatefulWidget {
  const ContactEdit({this.contact});

  final Contact contact;

  @override
  _ContactEditState createState() => _ContactEditState();
}

class _ContactEditState extends State<ContactEdit> {
  Contact editContact;
  String hashBeforeEdit;
  AddressBookProvider provider;
  String focusOn;
  final List<String> invalidFields = [];

  @override
  void initState() {
    editContact = widget.contact != null
        ? Contact.fromJson(widget.contact.toJson())
        : Contact();
    hashBeforeEdit = jsonEncode(editContact.toJson());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<AddressBookProvider>(context);

    return WillPopScope(
      onWillPop: () => _exitPage(),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: AppBar(
          title: Text(
            widget.contact == null
                ? 'Create Contact' // TODO(yurii): localization
                : 'Edit Contact', // TODO(yurii): localization
            key: const Key('contact_edit-title'),
          ),
          actions: <Widget>[
            if (widget.contact != null)
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _showDeleteConfiramtion(),
              ),
          ],
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    ContactEditField(
                        name: 'name',
                        label: 'Name',
                        invalid: invalidFields.contains('name'),
                        icon: Icon(
                          Icons.account_circle,
                          size: 16,
                          color: Theme.of(context).textTheme.body2.color,
                        ),
                        color: Theme.of(context).primaryColor,
                        value: editContact.name,
                        removable: false,
                        autofocus: widget.contact == null && focusOn == null,
                        onChange: (String value) {
                          setState(() {
                            editContact.name = value;
                          });
                          _validate();
                        }),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: _buildAddButton(),
                    ),
                    FutureBuilder<Widget>(
                      future: _buildAddresses(),
                      builder: (BuildContext context,
                          AsyncSnapshot<Widget> snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 1),
                              ),
                            ),
                          );

                        return snapshot.data;
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: Theme.of(context).primaryColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  FlatButton(
                    onPressed: () {
                      _exitPage();
                    },
                    child: const Text('Cancel'), // TODO(yurii): localization
                  ),
                  FlatButton(
                    onPressed: () {
                      _saveContact();
                    },
                    child: const Text('Save'), // TODO(yurii): localization
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _exitPage() async {
    final bool wasEdited = hashBeforeEdit != jsonEncode(editContact.toJson());
    if (wasEdited) {
      showConfirmationDialog(
          confirmButtonText: 'Discard', // TODO(yurii): localization
          context: context,
          icon: Icons.arrow_back,
          iconColor: Colors.white,
          title: 'Exit', // TODO(yurii): localization
          message: 'Discard your changes?',
          onConfirm: () {
            Navigator.of(context).pop();
          });
    } else {
      Navigator.of(context).pop();
    }

    return false;
  }

  bool _validate() {
    setState(() {
      invalidFields.clear();
    });
    bool valid = true;
    if (editContact.name == null || editContact.name.isEmpty) {
      valid = false;
      setState(() {
        invalidFields.add('name');
      });
    }
    editContact.addresses?.forEach((String abbr, String address) {
      if (address.isEmpty) {
        valid = false;
        setState(() {
          invalidFields.add(abbr);
        });
      }
    });

    return valid;
  }

  Future<Widget> _buildAddresses() async {
    if (editContact.addresses == null || editContact.addresses.isEmpty)
      return Container();

    final List<Widget> addresses = [];
    final List<Coin> coins = await coinsBloc.electrumCoins();

    for (var abbr in editContact.addresses.keys) {
      final String value = editContact.addresses[abbr];

      final String name = coins
          .firstWhere((Coin coin) => coin.abbr == abbr, orElse: () => null)
          ?.name;

      addresses.add(
        ContactEditField(
          name: abbr,
          label: name == null ? '$abbr' : '$name ($abbr)',
          value: value,
          padding: const EdgeInsets.only(
            top: 10,
            left: 16,
            right: 4,
          ),
          icon: abbr == null ? null : _buildCoinIcon(abbr),
          removable: true,
          onChange: (String value) {
            setState(() {
              editContact.addresses[abbr] = value;
            });
            _validate();
          },
          invalid: invalidFields.contains(abbr),
          onRemove: () {
            setState(() {
              focusOn = '';
              FocusScope.of(context).requestFocus(FocusNode());
            });
            editContact.addresses.removeWhere((k, v) => k == abbr);
          },
          autofocus: abbr == focusOn,
        ),
      );
    }

    return Column(
      children: [
        ...addresses,
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: _buildAddButton(),
        ),
      ],
    );
  }

  Widget _buildCoinIcon(String abbr) {
    return CircleAvatar(
      maxRadius: 8,
      backgroundImage: AssetImage('assets/${abbr.toLowerCase()}.png'),
    );
  }

  Widget _buildAddButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SmallButton(
          onPressed: () {
            _showCoinSelectDialog();
          },
          child: Row(
            children: <Widget>[
              Icon(Icons.add, size: 16),
              const Text('Add Address'), // TODO(yurii): localization
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCoinSelectDialog() async {
    setState(() {
      focusOn = '';
    });
    FocusScope.of(context).requestFocus(FocusNode());

    dialogBloc.dialog = showDialog(
        context: context,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        });

    final List<Coin> elCoins = await coinsBloc.electrumCoins();
    final List<Coin> coins = List.from(elCoins);
    coins.sort((Coin a, Coin b) => a.name.compareTo(b.name));
    dialogBloc.closeDialog(context);
    dialogBloc.dialog = showDialog(
        context: context,
        builder: (BuildContext context) {
          final List<SimpleDialogOption> coinsList = [];
          for (Coin coin in coins) {
            bool exist = false;
            if (editContact.addresses != null &&
                editContact.addresses.containsKey(coin.abbr)) {
              exist = true;
            }
            if (exist) continue;

            coinsList.add(SimpleDialogOption(
              onPressed: () {
                setState(() {
                  focusOn = coin.abbr;
                  editContact.addresses ??= {};
                  editContact.addresses[coin.abbr] = '';
                });
                dialogBloc.closeDialog(context);
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                  bottom: 8.0,
                ),
                child: Row(
                  children: <Widget>[
                    _buildCoinIcon(coin.abbr),
                    const SizedBox(width: 6),
                    Text(
                      coin.name,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ));
          }

          return SimpleDialog(
            title: const Text('Select Coin'), // TODO(yurii): localization
            children: [
              ...coinsList,
            ],
          );
        });
  }

  void _showDeleteConfiramtion() {
    showConfirmationDialog(
      context: context,
      title: 'Delete Contact', // TODO(yurii): localization
      icon: Icons.delete,
      message:
          'Are you sure you want to delete contact ${editContact.name}?', // TODO(yurii): localization
      confirmButtonText: 'Delete', // TODO(yurii): localization
      onConfirm: () => _deleteContact(),
    );
  }

  void _deleteContact() {
    if (widget.contact == null) return;
    provider.deleteContact(widget.contact);
    Navigator.of(context).pop();
  }

  void _saveContact() {
    if (!_validate()) return;

    if (widget.contact != null) {
      provider.updateContact(editContact);
    } else {
      provider.createContact(
        name: editContact.name,
        addresses: editContact.addresses,
      );
    }

    Navigator.of(context).pop();
  }
}
