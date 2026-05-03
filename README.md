</br>
<img width="1024" height="484" alt="image" src="https://github.com/user-attachments/assets/438221d6-f37e-4023-bf72-a4b47fe157f1" />

</br>

> [!TIP]
> **Optimization Tip:**
>
> - Ensure your input file contains full URLs (including schemes and parameters) for the best results.
> - Combine this with tools like `gau` or `waybackurls` to feed the engine a comprehensive dataset.
> - Check the `hits` count in the terminal to see which vulnerability classes are most prevalent in your target.

</br>
</br>

### TO-DO

* [ ] Add support for multi-threading to handle million+ URL lists.
* [ ] Integrate custom regex configuration via external YAML file.
* [ ] Add automated header checking for identified sensitive paths.

</br>
</br>

> [!CAUTION]
> **Use Link Categorizer only on assets you own or have explicit permission to test. This tool is designed for security researchers and bug bounty hunters to streamline reconnaissance. The authors are not responsible for any misuse or illegal activities.**## Link Categorizer

> [!NOTE]
> **Link Categorizer** is a high-performance bash-based intelligence engine designed to filter and categorize massive URL lists into specific vulnerability classes using professional-grade pattern matching.

</br>
</br>

### Features

* **Contextual Filtering:** Moves beyond simple keyword matching to use specific URL patterns, parameters, and sensitive paths[cite: 2].
* **Noise Reduction:** Automatically filters out static assets like images (`.jpg`, `.png`), fonts (`.woff`), and stylesheets (`.css`) to focus on actionable targets[cite: 2].
* **Vulnerability-Centric:** Pre-configured logic for SQLi, XSS, SSRF, IDOR, JWT leaks, and more[cite: 2].
* **Intelligence Layer:** High-precision regex for identifying state-changing paths and sensitive API endpoints[cite: 2].

</br>
</br>

### Installation

Clone the repository and ensure the script has execution permissions:
```bash
git clone [https://github.com/muhammadtaharana/link_categorizer](https://github.com/muhammadtaharana/link_categorizer)
cd link_categorizer
chmod +x link_categorizer.sh
```

</br>
</br>

### Vulnerability Categories

The engine automatically sorts hits into the following specialized modules:

| Category | Target Patterns |
| :--- | :--- |
| **SQLi** | Parameters like `id`, `query`, `select`, `order`, etc.[cite: 2] |
| **XSS** | Reflection points such as `search`, `msg`, `callback`, and `email`[cite: 2] |
| **SSRF** | URL/Domain handlers like `dest`, `proxy`, `uri`, and `site`[cite: 2] |
| **Auth/OAuth** | Critical paths like `/callback`, `/token`, and `/mfa`[cite: 2] |
| **JWT Leaks** | Scans for `ey...` encoded tokens within URL strings[cite: 2] |
| **Access Control** | IDOR-prone paths including `/v1/user/[id]` patterns[cite: 2] |

</br>
</br>

### Usage Examples

- ###### Categorize a file of URLs
```bash
./link_categorizer.sh urls.txt
```

- ###### Process output from other tools (e.g., waybackurls)
```bash
waybackurls example.com > urls.txt && ./link_categorizer.sh urls.txt
```

</br>
</br>

### Output Structure

The tool creates a directory named `extreme_categorized_urls` and populates it with individual files for each category[cite: 2]:

```text
extreme_categorized_urls/
├── sqli.txt
├── xss.txt
├── ssrf.txt
├── jwt_leaks.txt
└── ...
```

</br>
</br>

> [!TIP]
> **Optimization Tip:**
>
> - Ensure your input file contains full URLs (including schemes and parameters) for the best results.
> - Combine this with tools like `gau` or `waybackurls` to feed the engine a comprehensive dataset.
> - Check the `hits` count in the terminal to see which vulnerability classes are most prevalent in your target.

</br>
</br>

### TO-DO

* [ ] Add support for multi-threading to handle million+ URL lists.
* [ ] Integrate custom regex configuration via external YAML file.
* [ ] Add automated header checking for identified sensitive paths.

</br>
</br>

> [!CAUTION]
> **Use Link Categorizer only on assets you own or have explicit permission to test. This tool is designed for security researchers and bug bounty hunters to streamline reconnaissance. The authors are not responsible for any misuse or illegal activities.**[cite: 2]
```
