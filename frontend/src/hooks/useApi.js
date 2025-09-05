import { useState, useEffect } from "react";

export function useApi(endpoint) {
  const [data, setData] = useState(null);

  useEffect(() => {
    fetch(`/api/${endpoint}`)
      .then((res) => res.json())
      .then(setData)
      .catch(console.error);
  }, [endpoint]);

  return data;
}
