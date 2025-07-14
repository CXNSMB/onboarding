#!/bin/bash

echo "Test: Interactieve input in verschillende modi"
echo "=============================================="

echo "Test 1: Normale read"
echo -n "Voer iets in (test 1): "
read input1
echo "Je hebt ingevoerd: $input1"

echo ""
echo "Test 2: read -p"
read -p "Voer iets in (test 2): " input2
echo "Je hebt ingevoerd: $input2"

echo ""
echo "Test 3: Stdin terminal check"
if [ -t 0 ]; then
    echo "STDIN is een terminal"
    read -p "Voer iets in (test 3a): " input3a
    echo "Je hebt ingevoerd: $input3a"
else
    echo "STDIN is GEEN terminal"
    if [ -e /dev/tty ]; then
        echo "Probeer via /dev/tty"
        echo -n "Voer iets in (test 3b): "
        read input3b </dev/tty
        echo "Je hebt ingevoerd: $input3b"
    else
        echo "/dev/tty is niet beschikbaar"
    fi
fi

echo ""
echo "Alle tests voltooid!"
