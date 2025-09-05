import React, { useContext } from "react";
import { Routes, Route } from "react-router-dom";
import Navbar from "./components/Navbar";
import Home from "./pages/Home";
import About from "./pages/About";
import { ThemeContext } from "./context/ThemeContext";

function App() {
  const { darkMode } = useContext(ThemeContext);

  return (
    <div className={darkMode ? "dark bg-gray-900 text-white" : "bg-white text-black"}>
      <Navbar />
      <main className="p-4">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/about" element={<About />} />
        </Routes>
      </main>
    </div>
  );
}

export default App;
