const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  calculateRatingAggregate,
  resolveRatingTarget,
} = require("./rating");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const completedOrder = {
  passengerId: "passenger-1",
  driverId: "driver-1",
  status: "completed",
};

function resolve(overrides = {}) {
  return resolveRatingTarget({
    uid: "passenger-1",
    targetUserId: "driver-1",
    score: 5,
    orderData: completedOrder,
    HttpsError: TestHttpsError,
    ...overrides,
  });
}

function expectCode(code, callback) {
  assert.throws(callback, (error) => error.code === code);
}

describe("submitRating policy", () => {
  it("allows passenger to rate only the assigned driver", () => {
    assert.deepEqual(resolve(), {
      ratingField: "driverRating",
      targetUserId: "driver-1",
    });
  });

  it("allows driver to rate only the assigned passenger", () => {
    assert.deepEqual(resolve({
      uid: "driver-1",
      targetUserId: "passenger-1",
    }), {
      ratingField: "passengerRating",
      targetUserId: "passenger-1",
    });
  });

  it("denies duplicate, outsider, and self ratings", () => {
    expectCode("already-exists", () => resolve({
      orderData: {...completedOrder, driverRating: 4},
    }));
    expectCode("permission-denied", () => resolve({uid: "outsider"}));
    expectCode("permission-denied", () => resolve({
      targetUserId: "passenger-1",
    }));
  });

  it("denies invalid score and an incomplete order", () => {
    expectCode("invalid-argument", () => resolve({score: 0}));
    expectCode("failed-precondition", () => resolve({
      orderData: {...completedOrder, status: "in_progress"},
    }));
  });

  it("updates all rating aggregates from the same score", () => {
    assert.deepEqual(calculateRatingAggregate({
      rating: 4,
      ratingSum: 8,
      ratingCount: 2,
    }, 5), {
      rating: 13 / 3,
      ratingSum: 13,
      ratingCount: 3,
    });
  });
});
