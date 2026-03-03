#!/bin/bash

#############################################
# Otomatik Sistem Rapor Scripti v3.0
# Temizlenmiş ve Optimize Edilmiş Versiyon
#############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
CONFIG_FILE="$SCRIPT_DIR/config.conf"
CREDENTIALS_FILE="$SCRIPT_DIR/.mail_credentials"
TEMP_FILE=$(mktemp)

trap "rm -f $TEMP_FILE" EXIT
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"

#############################################
# FONKSİYONLAR
#############################################

yukle_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        dialog --msgbox "HATA: config.conf bulunamadi!" 7 40
        clear
        exit 1
    fi

    if [ -f "$CREDENTIALS_FILE" ]; then
        source "$CREDENTIALS_FILE"
    else
        dialog --msgbox "HATA: .mail_credentials bulunamadi!" 7 40
        clear
        exit 1
    fi
}

disk_kullanim() {
    echo "=== DISK KULLANIMI ===" >> "$LOG_FILE"
    df -h | grep -vE '^Filesystem|tmpfs|cdrom' >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    DISK_YUZDE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_YUZDE" -gt "$DISK_ESIK" ]; then
        echo "[UYARI] Disk kullanimi %$DISK_YUZDE (Esik: %$DISK_ESIK)" >> "$LOG_FILE"
        return 1
    fi
    return 0
}

bellek_durumu() {
    echo "=== BELLEK DURUMU ===" >> "$LOG_FILE"
    free -h >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    RAM_YUZDE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
    if [ "$RAM_YUZDE" -gt "$RAM_ESIK" ]; then
        echo "[UYARI] RAM kullanimi %$RAM_YUZDE (Esik: %$RAM_ESIK)" >> "$LOG_FILE"
        return 1
    fi
    return 0
}

sistem_suresi() {
    echo "=== SISTEM SURESI ===" >> "$LOG_FILE"
    uptime >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

aktif_kullanicilar() {
    echo "=== AKTIF KULLANICILAR ===" >> "$LOG_FILE"
    who >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

rapor_olustur() {
    ZAMAN_DAMGASI=$(date +%Y-%m-%d_%H%M%S)
    LOG_FILE="$LOG_DIR/$ZAMAN_DAMGASI.log"

    echo "######################################" > "$LOG_FILE"
    echo "# SISTEM RAPORU - $(date +%Y-%m-%d)" >> "$LOG_FILE"
    echo "# Hostname: $(hostname)" >> "$LOG_FILE"
    echo "# Rapor Saati: $(date '+%H:%M:%S')" >> "$LOG_FILE"
    echo "######################################" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    UYARI_VAR=0
    disk_kullanim || UYARI_VAR=1
    bellek_durumu || UYARI_VAR=1
    sistem_suresi
    aktif_kullanicilar

    echo "" >> "$LOG_FILE"
    if [ $UYARI_VAR -eq 1 ]; then
        echo "[!] DURUM: Kritik uyarilar var!" >> "$LOG_FILE"
    else
        echo "[OK] DURUM: Sistem normal calisiyor" >> "$LOG_FILE"
    fi
    echo "######################################" >> "$LOG_FILE"

    return $UYARI_VAR
}

mail_gonder() {
    rapor_olustur
    UYARI_DURUMU=$?

    if [ $UYARI_DURUMU -eq 1 ]; then
        KONU="[UYARI] Sistem Raporu - $(hostname) - $(date +%Y-%m-%d)"
    else
        KONU="Sistem Raporu - $(hostname) - $(date +%Y-%m-%d)"
    fi

    BASARILI=0
    BASARISIZ=0

    IFS=',' read -ra ALICI_ARRAY <<< "$EMAIL_ALICILAR"
    for ALICI in "${ALICI_ARRAY[@]}"; do
        ALICI=$(echo "$ALICI" | xargs)

        {
            echo "To: $ALICI"
            echo "From: $EMAIL_GONDEREN"
            echo "Subject: $KONU"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo ""
            cat "$LOG_FILE"
        } | ssmtp -v -au"$GMAIL_USER" -ap"$GMAIL_PASS" -f"$GMAIL_USER" "$ALICI" 2>&1 >/dev/null

        [ $? -eq 0 ] && ((BASARILI++)) || ((BASARISIZ++))
    done

    if [ $BASARISIZ -eq 0 ]; then
        dialog --msgbox "Mail basariyla gonderildi!\n\nBasarili: $BASARILI" 9 40
    else
        dialog --msgbox "Mail gonderimi tamamlandi.\n\nBasarili: $BASARILI\nBasarisiz: $BASARISIZ" 10 40
    fi
}

eski_loglari_temizle() {
    SILINEN=0
    for LOG in "$LOG_DIR"/*.log; do
        [ -f "$LOG" ] || continue
        DOSYA_YASI=$(( ($(date +%s) - $(stat -c %Y "$LOG")) / 86400 ))
        if [ $DOSYA_YASI -gt $LOG_SAKLAMA_GUN ]; then
            rm "$LOG"
            ((SILINEN++))
        fi
    done
    dialog --msgbox "$SILINEN adet eski log silindi\n($LOG_SAKLAMA_GUN gunden eski)" 8 40
}

gecmis_loglari_goster() {
    LOG_LIST=""
    LOG_SAYISI=0

    for LOG in "$LOG_DIR"/*.log; do
        if [ -f "$LOG" ]; then
            DOSYA=$(basename "$LOG")
            BOYUT=$(du -h "$LOG" | cut -f1)
            LOG_LIST="$LOG_LIST $DOSYA $BOYUT"
            ((LOG_SAYISI++))
        fi
    done

    if [ $LOG_SAYISI -eq 0 ]; then
        dialog --msgbox "Henuz log dosyasi yok." 7 35
        return
    fi

    dialog --menu "Gecmis Loglar ($LOG_SAYISI dosya)" 20 60 10 $LOG_LIST 2>$TEMP_FILE
    [ $? -eq 0 ] && dialog --textbox "$LOG_DIR/$(cat $TEMP_FILE)" 30 80
}

cron_kur_varsayilan() {
    CRON_LINE="0 8 * * * $SCRIPT_DIR/rapor5.sh --auto >> $LOG_DIR/cron.log 2>&1"

    if crontab -l 2>/dev/null | grep -q "0 8 .* $SCRIPT_DIR/rapor5.sh"; then
        dialog --msgbox "Saat 08:00 icin cron job zaten kurulu!" 8 45
    else
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        TOPLAM=$(crontab -l 2>/dev/null | grep "$SCRIPT_DIR/rapor5.sh" | wc -l)
        dialog --msgbox "Cron job kuruldu!\n\nSaat: 08:00\nToplam cron sayisi: $TOPLAM" 10 40
    fi
}

cron_kur_ozel() {
    dialog --inputbox "Saat girin (0-23):" 8 40 "14" 2>$TEMP_FILE
    [ $? -ne 0 ] && return
    SAAT=$(cat $TEMP_FILE)

    if ! [[ "$SAAT" =~ ^[0-9]+$ ]] || [ "$SAAT" -lt 0 ] || [ "$SAAT" -gt 23 ]; then
        dialog --msgbox "Gecersiz saat! (0-23 arasi olmali)" 7 40
        return
    fi

    dialog --inputbox "Dakika girin (0-59):" 8 40 "00" 2>$TEMP_FILE
    [ $? -ne 0 ] && return
    DAKIKA=$(cat $TEMP_FILE)

    if ! [[ "$DAKIKA" =~ ^[0-9]+$ ]] || [ "$DAKIKA" -lt 0 ] || [ "$DAKIKA" -gt 59 ]; then
        dialog --msgbox "Gecersiz dakika! (0-59 arasi olmali)" 7 40
        return
    fi

    CRON_LINE="$DAKIKA $SAAT * * * $SCRIPT_DIR/rapor5.sh --auto >> $LOG_DIR/cron.log 2>&1"

    if crontab -l 2>/dev/null | grep -q "$DAKIKA $SAAT .* $SCRIPT_DIR/rapor5.sh"; then
        dialog --msgbox "Saat $SAAT:$(printf "%02d" $DAKIKA) icin cron job zaten kurulu!" 8 50
    else
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        TOPLAM=$(crontab -l 2>/dev/null | grep "$SCRIPT_DIR/rapor5.sh" | wc -l)
        dialog --msgbox "Cron job kuruldu!\n\nSaat: $SAAT:$(printf "%02d" $DAKIKA)\nToplam cron sayisi: $TOPLAM" 10 45
    fi
}

cron_kaldir() {
    CRON_LISTESI=$(crontab -l 2>/dev/null | grep "$SCRIPT_DIR/rapor5.sh")

    if [ -z "$CRON_LISTESI" ]; then
        dialog --msgbox "Kurulu cron job bulunamadi." 7 35
        return
    fi

    CRON_SAYISI=$(echo "$CRON_LISTESI" | wc -l)

    if [ $CRON_SAYISI -eq 1 ]; then
        CRON_BILGI=$(echo "$CRON_LISTESI" | awk '{print $2":"$1}')
        dialog --yesno "Su cron job bulundu:\n\nSaat: $CRON_BILGI\n\nSilmek istiyor musunuz?" 10 50

        if [ $? -eq 0 ]; then
            crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/rapor5.sh" | crontab -
            dialog --msgbox "Cron job kaldirildi!" 7 30
        fi
    else
        MENU_ITEMS=""
        SAYAC=1

        while IFS= read -r CRON_LINE; do
            SAAT=$(echo "$CRON_LINE" | awk '{print $2":"$1}')
            MENU_ITEMS="$MENU_ITEMS $SAYAC \"Saat $SAAT\""
            ((SAYAC++))
        done <<< "$CRON_LISTESI"

        MENU_ITEMS="$MENU_ITEMS 0 \"HEPSINI SIL\""

        eval dialog --menu \"Silmek istediginiz cron job secin:\nToplam: $CRON_SAYISI adet\" 18 60 $((CRON_SAYISI + 1)) $MENU_ITEMS 2>$TEMP_FILE
        [ $? -ne 0 ] && return

        SECIM=$(cat $TEMP_FILE)

        if [ "$SECIM" == "0" ]; then
            dialog --yesno "TUM cron job'lari ($CRON_SAYISI adet) silmek istediginize emin misiniz?" 8 60
            if [ $? -eq 0 ]; then
                crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/rapor5.sh" | crontab -
                dialog --msgbox "Tum cron job'lar kaldirildi!" 7 35
            fi
        else
            SILINECEK=$(echo "$CRON_LISTESI" | sed -n "${SECIM}p")
            TEMP_CRON=$(mktemp)
            crontab -l 2>/dev/null | grep -v -F "$SILINECEK" > "$TEMP_CRON"
            crontab "$TEMP_CRON"
            rm -f "$TEMP_CRON"

            KALAN=$(crontab -l 2>/dev/null | grep "$SCRIPT_DIR/rapor5.sh" | wc -l)
            dialog --msgbox "Secili cron job kaldirildi!\n\nKalan cron sayisi: $KALAN" 9 40
        fi
    fi
}

anlik_rapor() {
    rapor_olustur
    dialog --textbox "$LOG_FILE" 30 80
}

#############################################
# ANA PROGRAM
#############################################

yukle_config

# Otomatik mod (cron için)
if [ "$1" == "--auto" ]; then
    BUGUN=$(date +%Y-%m-%d)
    LOG_FILE="$LOG_DIR/$BUGUN.log"

    echo "######################################" > "$LOG_FILE"
    echo "# SISTEM RAPORU - $BUGUN" >> "$LOG_FILE"
    echo "# Hostname: $(hostname)" >> "$LOG_FILE"
    echo "# Rapor Saati: $(date '+%H:%M:%S')" >> "$LOG_FILE"
    echo "######################################" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    UYARI_VAR=0
    disk_kullanim || UYARI_VAR=1
    bellek_durumu || UYARI_VAR=1
    sistem_suresi
    aktif_kullanicilar

    echo "" >> "$LOG_FILE"
    [ $UYARI_VAR -eq 1 ] && echo "[!] DURUM: Kritik uyarilar var!" >> "$LOG_FILE" || echo "[OK] DURUM: Sistem normal calisiyor" >> "$LOG_FILE"
    echo "######################################" >> "$LOG_FILE"

    [ $UYARI_VAR -eq 1 ] && KONU="[UYARI] Sistem Raporu - $(hostname) - $BUGUN" || KONU="Sistem Raporu - $(hostname) - $BUGUN"

    IFS=',' read -ra ALICI_ARRAY <<< "$EMAIL_ALICILAR"
    for ALICI in "${ALICI_ARRAY[@]}"; do
        ALICI=$(echo "$ALICI" | xargs)
        {
            echo "To: $ALICI"
            echo "From: $EMAIL_GONDEREN"
            echo "Subject: $KONU"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo ""
            cat "$LOG_FILE"
        } | ssmtp -v -au"$GMAIL_USER" -ap"$GMAIL_PASS" -f"$GMAIL_USER" "$ALICI" 2>&1 >/dev/null
    done

    for LOG in "$LOG_DIR"/*.log; do
        [ -f "$LOG" ] || continue
        DOSYA_YASI=$(( ($(date +%s) - $(stat -c %Y "$LOG")) / 86400 ))
        [ $DOSYA_YASI -gt $LOG_SAKLAMA_GUN ] && rm "$LOG"
    done

    exit 0
fi

# Dialog kontrolü
if ! command -v dialog &> /dev/null; then
    echo "HATA: dialog kurulu degil!"
    echo "Kurulum: sudo apt install dialog -y"
    exit 1
fi

# Ana menü
while true; do
    dialog --clear --title "SISTEM RAPOR YONETIMI" \
        --menu "Bir secenek secin:" 18 60 9 \
        1 "Anlik rapor goster" \
        2 "Rapor olustur ve kaydet" \
        3 "E-posta gonder" \
        4 "Gecmis loglari goruntule" \
        5 "Cron kur (saat 08:00)" \
        6 "Cron kur (ozel saat)" \
        7 "Cron job kaldir" \
        8 "Eski loglari temizle" \
        9 "Cikis" 2>$TEMP_FILE

    [ $? -ne 0 ] && clear && break

    case $(cat $TEMP_FILE) in
        1) anlik_rapor ;;
        2) rapor_olustur && dialog --msgbox "Rapor olusturuldu:\n\n$LOG_FILE" 9 60 ;;
        3) mail_gonder ;;
        4) gecmis_loglari_goster ;;
        5) cron_kur_varsayilan ;;
        6) cron_kur_ozel ;;
        7) cron_kaldir ;;
        8) eski_loglari_temizle ;;
        9) clear && echo "Gule gule!" && break ;;
    esac
done

exit 0
