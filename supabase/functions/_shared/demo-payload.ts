export const demoPayload = {
  detectedIngredients: [
    {
      id: crypto.randomUUID(),
      name: "Spinach",
      confidence: 0.98,
      note: null,
    },
    {
      id: crypto.randomUUID(),
      name: "Lettuce",
      confidence: 0.97,
      note: null,
    },
    {
      id: crypto.randomUUID(),
      name: "Eggs",
      confidence: 0.96,
      note: null,
    },
    {
      id: crypto.randomUUID(),
      name: "Oranges",
      confidence: 0.92,
      note: null,
    },
    {
      id: crypto.randomUUID(),
      name: "Lemons",
      confidence: 0.9,
      note: null,
    },
  ],
  uncertainIngredients: [],
  recipes: [
    {
      id: crypto.randomUUID(),
      title: "Warm Spinach and Lettuce Egg Salad",
      subtitle:
        "This is a light, fresh dish made from the greens and eggs visible in the photo. It is relatively simple because it uses only a few core items, requires very basic cooking, and does not depend on complicated seasoning or difficult technique.",
      usedIngredients: ["Spinach", "Lettuce", "Eggs", "Lemon or orange"],
      pantryAssumptions: ["Olive oil", "Salt", "Black pepper"],
      whyItWorks:
        "The fridge is already giving you a clean salad structure: tender greens, eggs for body, and citrus for brightness.",
      whyHealthy:
        "It stays vegetable-forward, protein-balanced, and relies on a light dressing rather than anything creamy or heavy.",
      whyDelicious:
        "Warm eggs against cool greens make the plate feel finished, while citrus keeps it bright and fresh.",
      timeMinutes: 12,
      steps: [
        "Bring a small pot of water to a gentle boil, then cook the eggs until just set and still tender in the center.",
        "Rinse and dry the spinach and lettuce, then tear the larger leaves and spread them across a wide plate or shallow bowl.",
        "Peel the eggs and cut them in halves or thick slices while they are still slightly warm.",
        "Whisk olive oil with a squeeze of lemon or orange juice, a pinch of salt, and a little black pepper.",
        "Lay the warm eggs over the greens and spoon the citrus dressing across the top just before serving.",
      ],
      finalResultDescription:
        "The finished dish should feel crisp, bright, and light, with soft warm eggs settling into the greens and a simple citrus dressing tying everything together.",
    },
  ],
  modelSummary:
    "Prototype analysis reads this fridge as greens, eggs, and citrus, which supports one clean, light recipe presentation.",
};
