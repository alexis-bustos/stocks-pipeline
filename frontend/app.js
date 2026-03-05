/**
 * Stock Movers Dashboard — Frontend Logic
 *
 * This script:
 *   1. Fetches the last 7 days of top movers from the API (GET /movers)
 *   2. Renders the "featured" card with today's top mover
 *   3. Populates the history table with all 7 days
 *   4. Color codes gains (green) and losses (red)
 *
 * IMPORTANT: Update API_URL after running 'terraform apply'.
 * You'll get the URL from: terraform output api_url
 */

// ============================================================
// CONFIGURATION — UPDATED THIS AFTER DEPLOYING
// ============================================================
const API_URL =
  "https://hk76xxomxh.execute-api.us-east-1.amazonaws.com/prod/movers";
// Example: "https://abc123.execute-api.us-east-1.amazonaws.com/prod/movers"
// Get this value by running: terraform output api_url

// ============================================================
// DOM References
// ============================================================
const statusBadge = document.getElementById("statusBadge");
const statusText = statusBadge.querySelector(".status-text");
const featuredCard = document.getElementById("featuredCard");
const featuredContent = document.getElementById("featuredContent");
const tableBody = document.getElementById("tableBody");

// ============================================================
// Helper Functions
// ============================================================

/**
 * Format a date string (YYYY-MM-DD) into a more readable format.
 * Example: "2026-03-03" → "Mon, Mar 3"
 */
function formatDate(dateStr) {
  const date = new Date(dateStr + "T00:00:00");
  return date.toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

/**
 * Format a number as a dollar amount.
 * Example: 248.5 → "$248.50"
 */
function formatPrice(price) {
  return "$" + Number(price).toFixed(2);
}

/**
 * Format the percent change with a + or - sign.
 * Example: 4.72 → "+4.72%", -2.31 → "-2.31%"
 */
function formatChange(change) {
  const sign = change >= 0 ? "+" : "";
  return sign + Number(change).toFixed(2) + "%";
}

/**
 * Determine if a change is a gain or loss.
 * Returns "gain" or "loss" — used as a CSS class.
 */
function changeClass(change) {
  return change >= 0 ? "gain" : "loss";
}

// ============================================================
// Render Functions
// ============================================================

/**
 * Render the featured "Today's Top Mover" card.
 */
function renderFeatured(mover) {
  const cls = changeClass(mover.percent_change);

  // Add gain/loss class to the card for the top border color
  featuredCard.classList.remove("gain", "loss");
  featuredCard.classList.add(cls);

  featuredContent.innerHTML = `
    <div class="fade-in">
      <div class="featured-ticker ${cls}">${mover.ticker}</div>
    </div>
    <div class="fade-in">
      <div class="featured-change ${cls}">${formatChange(mover.percent_change)}</div>
    </div>
    <div class="featured-meta fade-in">
      <div class="featured-meta-item">
        <span class="featured-meta-label">Close Price</span>
        <span class="featured-meta-value">${formatPrice(mover.close_price)}</span>
      </div>
      <div class="featured-meta-item">
        <span class="featured-meta-label">Date</span>
        <span class="featured-meta-value">${formatDate(mover.date)}</span>
      </div>
      <div class="featured-meta-item">
        <span class="featured-meta-label">Direction</span>
        <span class="featured-meta-value ${cls}">${mover.percent_change >= 0 ? "▲ Gain" : "▼ Loss"}</span>
      </div>
    </div>
  `;
}

/**
 * Render the 7-day history table.
 */
function renderTable(movers) {
  if (movers.length === 0) {
    tableBody.innerHTML = `
      <tr>
        <td colspan="4" class="error-message">No data available yet. The pipeline runs daily after market close.</td>
      </tr>
    `;
    return;
  }

  tableBody.innerHTML = movers
    .map(
      (mover) => `
      <tr>
        <td class="date-cell">${formatDate(mover.date)}</td>
        <td class="ticker-cell">${mover.ticker}</td>
        <td>
          <span class="change-pill ${changeClass(mover.percent_change)}">
            ${formatChange(mover.percent_change)}
          </span>
        </td>
        <td class="price-cell">${formatPrice(mover.close_price)}</td>
      </tr>
    `,
    )
    .join("");
}

/**
 * Update the status badge to show the current state.
 */
function setStatus(state, message) {
  statusBadge.className = "status-badge " + state;
  statusText.textContent = message;
}

/**
 * Show an error state in both the featured card and table.
 */
function showError(message) {
  setStatus("error", "Error");
  featuredContent.innerHTML = `<div class="error-message">${message}</div>`;
  tableBody.innerHTML = `
    <tr>
      <td colspan="4" class="error-message">${message}</td>
    </tr>
  `;
}

// ============================================================
// Fetch Data & Initialize
// ============================================================

async function fetchMovers() {
  try {
    const response = await fetch(API_URL);

    if (!response.ok) {
      throw new Error(`API returned status ${response.status}`);
    }

    const result = await response.json();
    const movers = result.data;

    if (!movers || movers.length === 0) {
      showError("No data available yet. Check back after market close.");
      return;
    }

    // The API returns newest first — index 0 is the most recent
    renderFeatured(movers[0]);
    renderTable(movers);
    setStatus("live", `${movers.length} days loaded`);
  } catch (error) {
    console.error("Failed to fetch movers:", error);
    showError(
      "Unable to connect to the API. Please check the API URL configuration.",
    );
  }
}

// --- Run on page load ---
fetchMovers();
