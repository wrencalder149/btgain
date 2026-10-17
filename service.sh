#!/system/bin/sh
# 開機寫一次就結束。true 才會關掉絕對音量，字串要比對前四個字。
resetprop persist.bluetooth.disableabsvol true
