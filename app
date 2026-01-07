import React, { useState, useRef } from 'react';
import { Camera, Upload, Loader2, Utensils, TrendingUp, Calendar, Target, Settings, X } from 'lucide-react';

export default function CalorieTracker() {
  const [image, setImage] = useState(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [result, setResult] = useState(null);
  const [history, setHistory] = useState([]);
  const [showGoalSetup, setShowGoalSetup] = useState(false);
  const [calorieGoal, setCalorieGoal] = useState(null);
  const [userName, setUserName] = useState('');
  const [goalForm, setGoalForm] = useState({
    name: '',
    age: '',
    gender: 'male',
    weight: '',
    height: '',
    activityLevel: 'moderate',
    goal: 'maintain'
  });
  const fileInputRef = useRef(null);
  const cameraInputRef = useRef(null);

  const calculateBMR = () => {
    const { age, gender, weight, height } = goalForm;
    if (!age || !weight || !height) return 0;

    // Mifflin-St Jeor Equation
    const weightKg = parseFloat(weight);
    const heightCm = parseFloat(height);
    const ageYears = parseInt(age);

    if (gender === 'male') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) + 5;
    } else {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 161;
    }
  };

  const calculateTDEE = () => {
    const bmr = calculateBMR();
    const activityMultipliers = {
      sedentary: 1.2,
      light: 1.375,
      moderate: 1.55,
      active: 1.725,
      veryActive: 1.9
    };
    return Math.round(bmr * activityMultipliers[goalForm.activityLevel]);
  };

  const calculateGoalCalories = () => {
    const tdee = calculateTDEE();
    const goalAdjustments = {
      lose: -500,
      maintain: 0,
      gain: 500
    };
    return tdee + goalAdjustments[goalForm.goal];
  };

  const handleSetGoal = () => {
    const targetCalories = calculateGoalCalories();
    setCalorieGoal(targetCalories);
    setUserName(goalForm.name);
    setShowGoalSetup(false);
  };

  const analyzeImage = async (imageData) => {
    setAnalyzing(true);
    setResult(null);

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 1000,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "image",
                  source: {
                    type: "base64",
                    media_type: "image/jpeg",
                    data: imageData
                  }
                },
                {
                  type: "text",
                  text: `Analyze this food image and provide a calorie estimate. Respond ONLY with a JSON object in this exact format (no markdown, no backticks, no extra text):
{
  "foodItems": ["item1", "item2"],
  "totalCalories": number,
  "breakdown": [
    {"item": "item1", "calories": number, "portion": "description"},
    {"item": "item2", "calories": number, "portion": "description"}
  ],
  "protein": number,
  "carbs": number,
  "fat": number,
  "confidence": "high/medium/low"
}`
                }
              ]
            }
          ]
        })
      });

      const data = await response.json();
      const text = data.content.map(item => item.type === "text" ? item.text : "").join("");
      const clean = text.replace(/```json|```/g, "").trim();
      const parsed = JSON.parse(clean);

      setResult(parsed);
      
      const entry = {
        id: Date.now(),
        timestamp: new Date().toISOString(),
        image: image,
        ...parsed
      };
      setHistory(prev => [entry, ...prev].slice(0, 10));
    } catch (error) {
      console.error("Analysis error:", error);
      setResult({
        error: "Unable to analyze image. Please try again with a clearer photo of food."
      });
    } finally {
      setAnalyzing(false);
    }
  };

  const handleFileSelect = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (event) => {
      const base64Data = event.target.result.split(',')[1];
      setImage(event.target.result);
      await analyzeImage(base64Data);
    };
    reader.readAsDataURL(file);
  };

  const getTodayTotal = () => {
    const today = new Date().toDateString();
    return history
      .filter(entry => new Date(entry.timestamp).toDateString() === today)
      .reduce((sum, entry) => sum + (entry.totalCalories || 0), 0);
  };

  const getCalorieProgress = () => {
    if (!calorieGoal) return 0;
    return Math.round((getTodayTotal() / calorieGoal) * 100);
  };

  const getRemainingCalories = () => {
    if (!calorieGoal) return 0;
    return calorieGoal - getTodayTotal();
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-blue-50 pb-20">
      <div className="max-w-2xl mx-auto p-4">
        {/* Header */}
        <div className="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="bg-green-500 p-3 rounded-full">
                <Utensils className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-800">
                  {userName ? `${userName}'s Tracker` : 'Calorie Tracker'}
                </h1>
                <p className="text-sm text-gray-600">Snap, analyze, track</p>
              </div>
            </div>
            <button
              onClick={() => setShowGoalSetup(true)}
              className="p-2 hover:bg-gray-100 rounded-full transition-colors"
            >
              <Settings className="w-6 h-6 text-gray-600" />
            </button>
          </div>
          
          {/* Daily Progress */}
          <div className="bg-gradient-to-r from-green-100 to-blue-100 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <div>
                <p className="text-sm text-gray-600 mb-1">Today's Total</p>
                <p className="text-3xl font-bold text-gray-800">{getTodayTotal()}</p>
                <p className="text-sm text-gray-600">
                  {calorieGoal ? `of ${calorieGoal} calories` : 'calories'}
                </p>
              </div>
              <Calendar className="w-12 h-12 text-green-600 opacity-50" />
            </div>

            {calorieGoal && (
              <div>
                <div className="flex justify-between text-sm text-gray-600 mb-2">
                  <span>{getCalorieProgress()}% of goal</span>
                  <span className={getRemainingCalories() >= 0 ? 'text-green-600' : 'text-red-600'}>
                    {getRemainingCalories() >= 0 ? `${getRemainingCalories()} left` : `${Math.abs(getRemainingCalories())} over`}
                  </span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-3">
                  <div
                    className={`h-3 rounded-full transition-all ${
                      getCalorieProgress() > 100 ? 'bg-red-500' : 'bg-gradient-to-r from-green-500 to-blue-500'
                    }`}
                    style={{ width: `${Math.min(getCalorieProgress(), 100)}%` }}
                  />
                </div>
              </div>
            )}

            {!calorieGoal && (
              <button
                onClick={() => setShowGoalSetup(true)}
                className="w-full mt-2 bg-white text-green-600 font-medium py-2 px-4 rounded-lg hover:bg-gray-50 transition-colors flex items-center justify-center gap-2"
              >
                <Target className="w-4 h-4" />
                Set Your Calorie Goal
              </button>
            )}
          </div>
        </div>

        {/* Goal Setup Modal */}
        {showGoalSetup && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full max-h-[90vh] overflow-y-auto">
              <div className="sticky top-0 bg-white border-b border-gray-200 p-4 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Target className="w-6 h-6 text-green-600" />
                  <h2 className="text-xl font-bold text-gray-800">Calculate Your Goal</h2>
                </div>
                <button
                  onClick={() => setShowGoalSetup(false)}
                  className="p-1 hover:bg-gray-100 rounded-full"
                >
                  <X className="w-6 h-6 text-gray-600" />
                </button>
              </div>

              <div className="p-6 space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Name</label>
                  <input
                    type="text"
                    value={goalForm.name}
                    onChange={(e) => setGoalForm({...goalForm, name: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                    placeholder="Your name"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Age</label>
                  <input
                    type="number"
                    value={goalForm.age}
                    onChange={(e) => setGoalForm({...goalForm, age: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                    placeholder="25"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Gender</label>
                  <select
                    value={goalForm.gender}
                    onChange={(e) => setGoalForm({...goalForm, gender: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  >
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Weight (kg)</label>
                  <input
                    type="number"
                    value={goalForm.weight}
                    onChange={(e) => setGoalForm({...goalForm, weight: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                    placeholder="70"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Height (cm)</label>
                  <input
                    type="number"
                    value={goalForm.height}
                    onChange={(e) => setGoalForm({...goalForm, height: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                    placeholder="175"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Activity Level</label>
                  <select
                    value={goalForm.activityLevel}
                    onChange={(e) => setGoalForm({...goalForm, activityLevel: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  >
                    <option value="sedentary">Sedentary (little/no exercise)</option>
                    <option value="light">Light (1-3 days/week)</option>
                    <option value="moderate">Moderate (3-5 days/week)</option>
                    <option value="active">Active (6-7 days/week)</option>
                    <option value="veryActive">Very Active (physical job/2x daily)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Goal</label>
                  <select
                    value={goalForm.goal}
                    onChange={(e) => setGoalForm({...goalForm, goal: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  >
                    <option value="lose">Lose Weight (-500 cal/day)</option>
                    <option value="maintain">Maintain Weight</option>
                    <option value="gain">Gain Weight (+500 cal/day)</option>
                  </select>
                </div>

                {goalForm.age && goalForm.weight && goalForm.height && (
                  <div className="bg-green-50 border border-green-200 rounded-xl p-4">
                    <p className="text-sm text-gray-600 mb-1">Your Target Calories</p>
                    <p className="text-3xl font-bold text-green-600">{calculateGoalCalories()}</p>
                    <p className="text-xs text-gray-500 mt-2">
                      Based on TDEE: {calculateTDEE()} cal/day
                    </p>
                  </div>
                )}

                <button
                  onClick={handleSetGoal}
                  disabled={!goalForm.age || !goalForm.weight || !goalForm.height}
                  className="w-full bg-gradient-to-r from-green-500 to-green-600 text-white font-medium py-3 px-4 rounded-lg hover:from-green-600 hover:to-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                >
                  Set Goal
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Camera Controls */}
        <div className="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Add Meal</h2>
          <div className="grid grid-cols-2 gap-4">
            <button
              onClick={() => cameraInputRef.current?.click()}
              className="flex flex-col items-center justify-center gap-2 bg-gradient-to-br from-green-500 to-green-600 text-white p-6 rounded-xl hover:from-green-600 hover:to-green-700 transition-all shadow-md"
            >
              <Camera className="w-8 h-8" />
              <span className="font-medium">Take Photo</span>
            </button>
            <button
              onClick={() => fileInputRef.current?.click()}
              className="flex flex-col items-center justify-center gap-2 bg-gradient-to-br from-blue-500 to-blue-600 text-white p-6 rounded-xl hover:from-blue-600 hover:to-blue-700 transition-all shadow-md"
            >
              <Upload className="w-8 h-8" />
              <span className="font-medium">Upload Photo</span>
            </button>
          </div>
          <input
            ref={cameraInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            onChange={handleFileSelect}
            className="hidden"
          />
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            onChange={handleFileSelect}
            className="hidden"
          />
        </div>

        {/* Analysis Result */}
        {(image || analyzing) && (
          <div className="bg-white rounded-2xl shadow-lg p-6 mb-6">
            {image && (
              <img
                src={image}
                alt="Food"
                className="w-full h-64 object-cover rounded-xl mb-4"
              />
            )}

            {analyzing && (
              <div className="flex flex-col items-center justify-center py-8 gap-3">
                <Loader2 className="w-12 h-12 text-green-500 animate-spin" />
                <p className="text-gray-600">Analyzing your meal...</p>
              </div>
            )}

            {result && !result.error && (
              <div className="space-y-4">
                <div className="bg-gradient-to-r from-green-500 to-blue-500 text-white rounded-xl p-6 text-center">
                  <p className="text-sm opacity-90 mb-1">Total Calories</p>
                  <p className="text-5xl font-bold">{result.totalCalories}</p>
                  <p className="text-sm opacity-90 mt-2">
                    Confidence: {result.confidence}
                  </p>
                </div>

                <div className="grid grid-cols-3 gap-3">
                  <div className="bg-red-50 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-600 mb-1">Protein</p>
                    <p className="text-xl font-bold text-red-600">{result.protein}g</p>
                  </div>
                  <div className="bg-yellow-50 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-600 mb-1">Carbs</p>
                    <p className="text-xl font-bold text-yellow-600">{result.carbs}g</p>
                  </div>
                  <div className="bg-purple-50 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-600 mb-1">Fat</p>
                    <p className="text-xl font-bold text-purple-600">{result.fat}g</p>
                  </div>
                </div>

                <div>
                  <h3 className="font-semibold text-gray-800 mb-3">Breakdown</h3>
                  <div className="space-y-2">
                    {result.breakdown.map((item, idx) => (
                      <div key={idx} className="flex justify-between items-center bg-gray-50 rounded-lg p-3">
                        <div>
                          <p className="font-medium text-gray-800">{item.item}</p>
                          <p className="text-xs text-gray-500">{item.portion}</p>
                        </div>
                        <p className="font-bold text-green-600">{item.calories} cal</p>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {result?.error && (
              <div className="bg-red-50 border border-red-200 rounded-xl p-4 text-red-700">
                {result.error}
              </div>
            )}
          </div>
        )}

        {/* History */}
        {history.length > 0 && (
          <div className="bg-white rounded-2xl shadow-lg p-6">
            <div className="flex items-center gap-2 mb-4">
              <TrendingUp className="w-5 h-5 text-gray-600" />
              <h2 className="text-lg font-semibold text-gray-800">Recent Meals</h2>
            </div>
            <div className="space-y-3">
              {history.map((entry) => (
                <div key={entry.id} className="flex gap-3 bg-gray-50 rounded-xl p-3">
                  <img
                    src={entry.image}
                    alt="Meal"
                    className="w-20 h-20 object-cover rounded-lg"
                  />
                  <div className="flex-1">
                    <p className="font-medium text-gray-800">
                      {entry.foodItems.join(', ')}
                    </p>
                    <p className="text-sm text-gray-500">
                      {new Date(entry.timestamp).toLocaleTimeString([], {
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </p>
                    <p className="text-lg font-bold text-green-600 mt-1">
                      {entry.totalCalories} cal
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
