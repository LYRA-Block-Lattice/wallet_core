import 'dart:async';
import 'package:http/http.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart';

class Web3 {
  Web3Client _client;
  Future<bool> _approveCb;
  Credentials _credentials;
  num _networkId;

  Web3(String url, num networkId, Future<bool> approveCb()) {
    _client = new Web3Client(url, new Client());
    _approveCb = approveCb();
    _networkId = networkId;
  }

  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  String privateKeyFromMnemonic(String mnemonic) {
    String seed = bip39.mnemonicToSeedHex(mnemonic);
    bip32.BIP32 root = bip32.BIP32.fromSeed(HEX.decode(seed));
    bip32.BIP32 child = root.derivePath("m/44'/60'/0'/0/0");
    String privateKey = HEX.encode(child.privateKey);
    return privateKey;
  }

  Future<void> setCredentials(String privateKey) async {
    _credentials = await _client.credentialsFromPrivateKey(privateKey);
  }

  Future<String> sendTransactionAndWaitForReceipt(
      Transaction transaction) async {
    print('sendTransactionAndWaitForReceipt');
    String txHash = await _client.sendTransaction(_credentials, transaction,
        chainId: _networkId);
    TransactionReceipt receipt = await _client.getTransactionReceipt(txHash);
    num delay = 1;
    num retries = 5;
    while (receipt == null) {
      print('waiting for receipt');
      await Future.delayed(new Duration(seconds: delay));
      delay *= 2;
      retries--;
      if (retries == 0) {
        throw 'transaction $txHash not mined...';
      }
      try {
        receipt = await _client.getTransactionReceipt(txHash);
      } catch (err) {
        print('could not get $txHash receipt, try again');
      }
    }
    return txHash;
  }

  Future<String> transferNative(String receiverAddress, num amountInWei) async {
    print(
        'transferNative --> receiver: $receiverAddress, amountInWei: $amountInWei');

    bool isApproved = await _approveCb;
    if (!isApproved) {
      throw 'transaction not approved';
    }

    EthereumAddress receiver = EthereumAddress.fromHex(receiverAddress);
    EtherAmount amount =
        EtherAmount.fromUnitAndValue(EtherUnit.wei, BigInt.from(amountInWei));

    String txHash = await sendTransactionAndWaitForReceipt(
        Transaction(to: receiver, value: amount));
    print('transction $txHash successful');
    return txHash;
  }

  Future<String> getAddress() async {
    return (await _credentials.extractAddress()).toString();
  }

  Future<EtherAmount> getBalance() async {
    EthereumAddress address = await _credentials.extractAddress();
    return _client.getBalance(address);
  }
}
