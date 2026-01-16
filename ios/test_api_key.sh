#!/bin/bash

# Test Google Places API Key
# Run this script to verify your API key works

API_KEY="AIzaSyANwdUer4vuMh4xilyROQlYZyProyrZ7VI"

echo "🧪 Testing Google Places API Key..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test Autocomplete API
echo "📍 Testing Places Autocomplete API..."
response=$(curl -s "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Lane%20Cove&key=${API_KEY}")

# Check for error
if echo "$response" | grep -q "REQUEST_DENIED"; then
    echo "❌ FAILED: REQUEST_DENIED"
    echo ""
    echo "Possible causes:"
    echo "  1. Places API not enabled in Google Cloud Console"
    echo "  2. API key has restrictions that block this request"
    echo "  3. Billing not enabled (required for Places API)"
    echo ""
    echo "Full response:"
    echo "$response" | python3 -m json.tool
    exit 1
elif echo "$response" | grep -q "INVALID_REQUEST"; then
    echo "❌ FAILED: INVALID_REQUEST"
    echo "API key might be invalid or malformed"
    exit 1
elif echo "$response" | grep -q "predictions"; then
    echo "✅ SUCCESS: API key works!"
    echo ""
    echo "Predictions found:"
    echo "$response" | python3 -m json.tool | grep "description" | head -5
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Your API key is working correctly."
    echo ""
    echo "If your iOS app still shows 'Internal Error', the issue is:"
    echo "  • Bundle ID restriction in Google Cloud Console doesn't match your Xcode bundle ID"
    echo ""
    echo "Fix:"
    echo "  1. Find your bundle ID in Xcode (Project → Target → General → Bundle Identifier)"
    echo "  2. Add it to your API key restrictions in Google Cloud Console"
    echo "  3. Make sure 'Places API' is checked under API restrictions"
    exit 0
else
    echo "❌ UNEXPECTED RESPONSE"
    echo "$response" | python3 -m json.tool
    exit 1
fi
