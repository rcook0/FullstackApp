import React, { useContext } from "react";
import { Link } from "react-router-dom";
import { ThemeContext } from "../context/ThemeContext";

function Navbar() {
  const { darkMode, setDarkMode } = useContext(ThemeContext);

  return (
    <nav className="flex justify-between p-4 shadow">
      <div>
        <Link to="/" className="mr-4">Home</Link>
        <Link to="/about">About</Link>
      </div>
      <button
        className="px-2 py-1 border rounded"
        onClick={() => setDarkMode(!darkMode)}
      >
        {darkMode ? "Light Mode" : "Dark Mode"}
      </button>
    </nav>
  );
}

export default Navbar;
