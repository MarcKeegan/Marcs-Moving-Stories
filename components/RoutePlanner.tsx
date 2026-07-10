/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import React, { useState, useRef, useEffect } from 'react';
import { MapPin, Navigation, Loader2, Footprints, Car, CloudRain, Sparkles, ScrollText, Sword, Locate, Library } from 'lucide-react';
import { RouteDetails, AppState, StoryStyle, TravelMode } from '../types';
import { useGoogleMaps } from '../hooks/useGoogleMaps';

interface Props {
  onRouteFound: (details: RouteDetails, directions: google.maps.DirectionsResult) => void;
  appState: AppState;
  externalError?: string | null;
}

const STYLES: { id: StoryStyle; label: string; icon: React.ElementType; desc: string }[] = [
  { id: 'NOIR', label: 'Noir Thriller', icon: CloudRain, desc: 'Gritty, mysterious, rain-slicked streets.' },
  { id: 'CHILDREN', label: 'Children\'s Story', icon: Sparkles, desc: 'Whimsical, magical, and full of wonder.' },
  { id: 'HISTORICAL', label: 'Historical Epic', icon: ScrollText, desc: 'Grand, dramatic, echoing the past.' },
  { id: 'FANTASY', label: 'Fantasy Adventure', icon: Sword, desc: 'An epic quest through a magical realm.' },
  { id: 'HISTORIAN_GUIDE', label: 'Historian Guide', icon: Library, desc: 'Factual, authoritative, and deeply researched.' },
];

// 4 hours limit to prevent generation timeouts
const MAX_JOURNEY_SECONDS = 14400;

const RoutePlanner: React.FC<Props> = ({ onRouteFound, appState, externalError }) => {
  const [startAddress, setStartAddress] = useState('');
  const [endAddress, setEndAddress] = useState('');
  const [travelMode, setTravelMode] = useState<TravelMode>('WALKING');
  const [selectedStyle, setSelectedStyle] = useState<StoryStyle>('NOIR');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isLocating, setIsLocating] = useState(false);

  const startInputRef = useRef<HTMLInputElement>(null);
  const endInputRef = useRef<HTMLInputElement>(null);

  const { ready: mapsReady } = useGoogleMaps();

  // Sync external errors (like timeouts from the story engine) into local UI
  useEffect(() => {
    if (externalError) {
      setError(externalError);
    }
  }, [externalError]);

  // Initialize Classic Autocomplete once Maps is ready
  useEffect(() => {
    if (!mapsReady || !window.google?.maps?.places) return;

    let isMounted = true;

    try {
      const setupAutocomplete = (
        inputElement: HTMLInputElement | null,
        setAddress: (addr: string) => void
      ) => {
        if (!inputElement) return;

        const autocomplete = new google.maps.places.Autocomplete(inputElement, {
          fields: ['formatted_address', 'geometry', 'name'],
          types: ['geocode', 'establishment']
        });

        autocomplete.addListener('place_changed', () => {
          if (!isMounted) return;
          const place = autocomplete.getPlace();

          if (!place.geometry || !place.geometry.location) {
            if (inputElement.value) {
              const geocoder = new google.maps.Geocoder();
              geocoder.geocode({ address: inputElement.value }, (results, status) => {
                if (isMounted && status === 'OK' && results && results[0]) {
                  setAddress(results[0].formatted_address);
                }
              });
            }
            return;
          }

          const address = place.formatted_address || place.name || '';
          setAddress(address);
        });
      };

      setupAutocomplete(startInputRef.current, setStartAddress);
      setupAutocomplete(endInputRef.current, setEndAddress);
    } catch (e) {
      console.error('Failed to initialize Places Autocomplete:', e);
      if (isMounted) setError('Location search failed to initialize. Please refresh.');
    }

    return () => { isMounted = false; };
  }, [mapsReady]);

  const handleCalculate = () => {
    if (!startAddress || !endAddress) {
      setError('Please search for and select both a start and end location.');
      return;
    }

    if (!mapsReady || !window.google?.maps) {
      setError('Google Maps API is not loaded yet. Please refresh.');
      return;
    }

    setError(null);
    setIsLoading(true);

    const directionsService = new google.maps.DirectionsService();
    directionsService.route(
      {
        origin: startAddress,
        destination: endAddress,
        travelMode: google.maps.TravelMode[travelMode],
      },
      (result, status) => {
        setIsLoading(false);
        if (status === google.maps.DirectionsStatus.OK && result) {
          const leg = result.routes[0]?.legs[0];
          if (!leg?.duration || !leg.distance) {
            setError('Could not calculate route. Please check the locations and try again.');
            return;
          }

          if (leg.duration.value > MAX_JOURNEY_SECONDS) {
            setError('Sorry, this journey is too long. Please select a route under 4 hours.');
            return;
          }

          // The full DirectionsResult is passed up so the maps can render it
          // without issuing duplicate (billed) Directions requests.
          onRouteFound({
            startAddress: leg.start_address,
            endAddress: leg.end_address,
            distance: leg.distance.text,
            duration: leg.duration.text,
            durationSeconds: leg.duration.value,
            travelMode: travelMode,
            voiceName: 'Kore',
            storyStyle: selectedStyle
          }, result);
        } else {
          console.error('Directions error:', status);
          if (status === 'ZERO_RESULTS') {
            const mode = travelMode.toLowerCase();
            setError(`Sorry, we could not calculate ${mode} directions from "${startAddress}" to "${endAddress}"`);
          } else {
            setError('Could not calculate route. Please check the locations and try again.');
          }
        }
      }
    );
  };

  const handleUseCurrentLocation = () => {
    if (!navigator.geolocation) {
      setError('Geolocation is not supported by your browser');
      return;
    }

    setIsLocating(true);
    setError(null);

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        if (window.google?.maps) {
          const geocoder = new google.maps.Geocoder();
          geocoder.geocode({ location: { lat: latitude, lng: longitude } }, (results, status) => {
            if (status === 'OK' && results && results[0]) {
              setStartAddress(results[0].formatted_address);
            } else {
              setError('Could not find address for your location');
            }
            setIsLocating(false);
          });
        } else {
          setError('Google Maps API not loaded');
          setIsLocating(false);
        }
      },
      (geoError) => {
        console.error('Geolocation error:', geoError);
        setError('Unable to retrieve your location. Please check permissions.');
        setIsLocating(false);
      }
    );
  };

  const isLocked = appState !== AppState.PLANNING;

  return (
    <div className={`transition-all duration-700 ${isLocked ? 'opacity-50 pointer-events-none grayscale' : ''}`}>
      <div className="space-y-8 bg-white/80 backdrop-blur-lg p-8 md:p-10 rounded-[2rem] shadow-2xl shadow-stone-200/50 border border-white/50">
        <div className="space-y-1">
          <h2 className="text-2xl font-display text-editorial-900">Plan Your Journey</h2>
          <p className="text-stone-500">Search locations and customize your experience.</p>
        </div>

        <div className="space-y-4">
          <div className="relative group z-20 h-14 bg-stone-50/50 border-2 border-stone-100 focus-within:border-editorial-900 focus-within:bg-white rounded-xl transition-all shadow-sm focus-within:shadow-md overflow-hidden">
            <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-stone-400 group-focus-within:text-editorial-900 transition-colors pointer-events-none z-10" size={20} />
            <label htmlFor="route-start" className="sr-only">Starting point</label>
            <input
              id="route-start"
              ref={startInputRef}
              type="text"
              placeholder="Starting Point"
              className="w-full h-full bg-transparent p-0 pl-12 pr-12 text-editorial-900 placeholder-stone-400 outline-none font-medium text-base"
              value={startAddress}
              onChange={(e) => setStartAddress(e.target.value)}
              disabled={isLocked}
            />
            <button
              onClick={handleUseCurrentLocation}
              disabled={isLocked || isLocating}
              className="absolute right-2 top-1/2 -translate-y-1/2 p-2 rounded-full text-stone-400 hover:text-editorial-900 hover:bg-stone-100 transition-all disabled:opacity-50 disabled:cursor-not-allowed z-20"
              title="Use current location"
              aria-label="Use current location"
            >
              {isLocating ? (
                <Loader2 size={18} className="animate-spin" />
              ) : (
                <Locate size={18} />
              )}
            </button>
          </div>

          <div className="relative group z-10 h-14 bg-stone-50/50 border-2 border-stone-100 focus-within:border-editorial-900 focus-within:bg-white rounded-xl transition-all shadow-sm focus-within:shadow-md overflow-hidden">
            <Navigation className="absolute left-4 top-1/2 -translate-y-1/2 text-stone-400 group-focus-within:text-editorial-900 transition-colors pointer-events-none z-10" size={20} />
            <label htmlFor="route-end" className="sr-only">Destination</label>
            <input
              id="route-end"
              ref={endInputRef}
              type="text"
              placeholder="Destination"
              className="w-full h-full bg-transparent p-0 pl-12 pr-4 text-editorial-900 placeholder-stone-400 outline-none font-medium text-base"
              value={endAddress}
              onChange={(e) => setEndAddress(e.target.value)}
              disabled={isLocked}
            />
          </div>
        </div>

        {/* Settings Grid */}
        <div className="grid grid-cols-1 gap-6">
          {/* Travel Mode */}
          <div className="space-y-3">
            <span className="block text-sm font-medium text-stone-500 uppercase tracking-wider">Travel Mode</span>
            <div className="flex gap-2 bg-stone-100/50 p-1.5 rounded-xl border border-stone-100">
              {(['WALKING', 'DRIVING'] as TravelMode[]).map((mode) => (
                <button
                  key={mode}
                  onClick={() => setTravelMode(mode)}
                  disabled={isLocked}
                  aria-pressed={travelMode === mode}
                  className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg font-medium text-sm transition-all ${travelMode === mode
                    ? 'bg-white text-editorial-900 shadow-md'
                    : 'text-stone-500 hover:bg-stone-200/50 hover:text-stone-700'
                    }`}
                >
                  {mode === 'WALKING' && <Footprints size={18} />}
                  {mode === 'DRIVING' && <Car size={18} />}
                  <span className="hidden lg:inline">
                    {mode === 'WALKING' ? 'Walk' : 'Drive'}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Story Style Selector */}
        <div className="space-y-3">
          <span className="block text-sm font-medium text-stone-500 uppercase tracking-wider">Story Style</span>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {STYLES.map((style) => {
              const Icon = style.icon;
              const isSelected = selectedStyle === style.id;
              return (
                <button
                  key={style.id}
                  onClick={() => setSelectedStyle(style.id)}
                  disabled={isLocked}
                  aria-pressed={isSelected}
                  className={`flex items-start gap-3 p-4 rounded-xl border-2 text-left transition-all ${isSelected
                    ? 'border-editorial-900 bg-editorial-900 text-white shadow-md'
                    : 'border-stone-100 bg-stone-50/50 text-stone-600 hover:border-stone-300 hover:bg-stone-100'
                    }`}
                >
                  <Icon size={24} className={`shrink-0 ${isSelected ? 'text-white' : 'text-stone-400'}`} />
                  <div>
                    <div className={`font-bold ${isSelected ? 'text-white' : 'text-editorial-900'}`}>
                      {style.label}
                    </div>
                    <div className={`text-xs mt-1 leading-tight ${isSelected ? 'text-stone-300' : 'text-stone-500'}`}>
                      {style.desc}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {error && (
          <p role="alert" className="text-red-600 text-sm bg-red-50 p-3 rounded-lg font-medium animate-fade-in">{error}</p>
        )}

        <button
          onClick={handleCalculate}
          disabled={isLoading || isLocked || !startAddress || !endAddress}
          className="w-full bg-editorial-900 text-white py-4 rounded-full font-bold text-lg hover:bg-stone-800 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 shadow-lg shadow-editorial-900/20 active:scale-[0.99]"
        >
          {isLoading ? (
            <>
              <Loader2 className="animate-spin" /> Planning Journey...
            </>
          ) : (
            <>
              <Sparkles size={20} className="animate-subtle-pulse" />
              Create your story
            </>
          )}
        </button>
      </div>
    </div>
  );
};

export default RoutePlanner;
