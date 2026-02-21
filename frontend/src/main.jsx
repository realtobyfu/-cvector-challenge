import React from "react";
import ReactDOM from "react-dom/client";
import { ConfigProvider } from "antd";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: "#1a7a4f",
          colorBgBase: "#ffffff",
          colorBgContainer: "#ffffff",
          colorBgElevated: "#ffffff",
          colorBorder: "#e2dfda",
          colorText: "#1a1a1a",
          colorTextSecondary: "#5c5752",
          fontFamily: "'IBM Plex Mono', monospace",
          fontFamilyCode: "'IBM Plex Mono', monospace",
          borderRadius: 0,
          fontSize: 13,
        },
        components: {
          Card: {
            colorBgContainer: "#ffffff",
            colorBorderSecondary: "#e2dfda",
          },
          Table: {
            colorBgContainer: "#ffffff",
            headerBg: "#f7f6f4",
          },
          Select: {
            colorBgContainer: "#ffffff",
          },
        },
      }}
    >
      <App />
    </ConfigProvider>
  </React.StrictMode>
);
